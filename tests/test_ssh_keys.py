"""Integration tests use disposable keys and a PTY without a controlling TTY.

Run with age, script and ssh-keygen in PATH, using Python's unittest discovery.
"""

import json
import os
from pathlib import Path
import pty
import select
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import unittest


HELPER = Path(__file__).resolve().parents[1] / "scripts/ssh-keys.py"
NAMES = ("personal", "bitbucket_work", "othinus")
PASSPHRASE = "disposable test archive passphrase 94b271"


class SSHKeysTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir="/dev/shm")
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.repo, self.home, self.source = root / "repo", root / "home", root / "source"
        (self.repo / "config/ssh").mkdir(parents=True)
        self.source.mkdir()
        (self.repo / "config/ssh/config").write_text("Host *\n  IdentitiesOnly yes\n")
        for name in NAMES:
            subprocess.run([
                shutil.which("ssh-keygen"), "-q", "-t", "ed25519", "-N",
                "separate SSH passphrase" if name == "personal" else "",
                "-f", str(self.source / name),
            ], check=True)
            shutil.copyfile(self.source / f"{name}.pub", self.repo / f"config/ssh/{name}.pub")
        self.command = [sys.executable, str(HELPER), "--repo", str(self.repo),
                        "--home", str(self.home), "--source", str(self.source)]
        for name in ("age", "script", "ssh-keygen"):
            self.command += [f"--{name}", shutil.which(name)]

    def run_helper(self, answers=None):
        if answers is None:
            result = subprocess.run(self.command, stdin=subprocess.DEVNULL, capture_output=True)
            return result.returncode, (result.stdout + result.stderr).decode()
        master, slave = pty.openpty()
        # Like systemd-run --pipe: terminal descriptors, no controlling TTY.
        process = subprocess.Popen(self.command, stdin=slave, stdout=slave, stderr=slave,
                                   start_new_session=True)
        os.close(slave)
        output = b""
        answered = 0
        deadline = time.monotonic() + 30
        try:
            while time.monotonic() < deadline:
                if select.select([master], [], [], 0.1)[0]:
                    try:
                        chunk = os.read(master, 65536)
                    except OSError:
                        break
                    if not chunk:
                        break
                    output += chunk
                    prompts = output.count(b"Enter passphrase") + output.count(b"Confirm passphrase")
                    if prompts > answered and answered < len(answers):
                        os.write(master, answers[answered].encode() + b"\n")
                        answered += 1
                if process.poll() is not None:
                    break
            else:
                self.fail("Interactive helper timed out: " + output.decode(errors="replace"))
            process.wait(timeout=5)
            for answer in answers:
                self.assertNotIn(answer.encode(), output, "Passphrase was echoed")
            return process.returncode, output.decode(errors="replace")
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            os.close(master)

    def encrypt(self):
        code, output = self.run_helper([PASSPHRASE, PASSPHRASE])
        self.assertEqual(code, 0, output)
        ciphertext = (self.repo / "secrets/ssh-keys.age").read_bytes()
        self.assertTrue(ciphertext.startswith(b"age-encryption.org/v1"))
        self.assertNotIn(b"PRIVATE KEY", ciphertext)

    def assert_installed(self):
        for name in NAMES:
            path = self.home / f".ssh/{name}"
            self.assertEqual(path.read_bytes(), (self.source / name).read_bytes())
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE((self.home / ".ssh").stat().st_mode), 0o700)
        self.assertEqual((self.home / ".ssh/config").resolve(), self.repo / "config/ssh/config")

    def test_create_restore_and_repeat_without_terminal(self):
        self.encrypt()
        self.assert_installed()
        code, output = self.run_helper()
        self.assertEqual(code, 0, output)
        self.assertIn("no passphrase needed", output)
        shutil.rmtree(self.home)
        code, output = self.run_helper([PASSPHRASE])
        self.assertEqual(code, 0, output)
        self.assert_installed()
        (self.home / ".ssh/config").write_text("Host edited\n")
        self.assertEqual((self.repo / "config/ssh/config").read_text(), "Host edited\n")

    def test_wrong_passphrase_and_missing_terminal_preserve_existing_keys(self):
        self.encrypt()
        missing = self.home / ".ssh/othinus"
        missing.unlink()
        personal = (self.home / ".ssh/personal").read_bytes()
        code, output = self.run_helper()
        self.assertNotEqual(code, 0)
        self.assertIn("interactive terminal", output)
        code, output = self.run_helper(["wrong disposable passphrase"])
        self.assertNotEqual(code, 0, output)
        self.assertFalse(missing.exists())
        self.assertEqual((self.home / ".ssh/personal").read_bytes(), personal)
        code, output = self.run_helper([PASSPHRASE])
        self.assertEqual(code, 0, output)
        self.assert_installed()

    def test_public_key_mismatch_aborts_without_replacing_keys(self):
        self.encrypt()
        state = (self.home / ".local/state/ssh-keys/installed.json").read_bytes()
        shutil.copyfile(self.repo / "config/ssh/othinus.pub", self.repo / "config/ssh/personal.pub")
        code, output = self.run_helper([PASSPHRASE])
        self.assertNotEqual(code, 0, output)
        self.assertIn("does not match", output)
        self.assertEqual((self.home / ".local/state/ssh-keys/installed.json").read_bytes(), state)
        self.assert_installed()

    def test_existing_config_and_keys_backed_up(self):
        (self.home / ".ssh").mkdir(parents=True)
        (self.home / ".ssh/config").write_text("old config")
        (self.home / ".ssh/othinus").write_text("old key")
        self.encrypt()
        self.assert_installed()
        self.assertEqual(next((self.home / ".ssh").glob("config.before-nixos-*")).read_text(), "old config")
        self.assertEqual(next((self.home / ".ssh").glob("othinus.before-nixos-*")).read_text(), "old key")

    def test_group_writable_config_repaired_even_when_keys_are_current(self):
        self.encrypt()
        config = self.repo / "config/ssh/config"
        config.chmod(0o664)
        code, output = self.run_helper()
        self.assertEqual(code, 0, output)
        self.assertEqual(stat.S_IMODE(config.stat().st_mode), 0o644)

    def test_changed_bundle_prompts_again(self):
        self.encrypt()
        old_digest = json.loads((self.home / ".local/state/ssh-keys/installed.json").read_text())["bundle"]
        (self.repo / "secrets/ssh-keys.age").unlink()
        self.encrypt()
        new_digest = json.loads((self.home / ".local/state/ssh-keys/installed.json").read_text())["bundle"]
        self.assertNotEqual(old_digest, new_digest)


if __name__ == "__main__":
    unittest.main()
