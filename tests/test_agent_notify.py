import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time
import unittest


NOTIFIER = (
    Path(__file__).resolve().parents[1] / "config/agents/hooks/notification/common.sh"
)


class AgentNotifyTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="agent-notify-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.runtime = self.root / "runtime"
        self.runtime.mkdir()
        self.calls = self.root / "calls"
        self.env = dict(
            os.environ, XDG_RUNTIME_DIR=str(self.runtime), CALLS=str(self.calls)
        )
        self.env["DBUS_SESSION_BUS_ADDRESS"] = "unix:path=/incorrect/ssh/bus"
        self.env["PATH"] = f"{self.root}:{self.env['PATH']}"

    def desktop(self):
        bus = socket.socket(socket.AF_UNIX)
        bus.bind(str(self.runtime / "bus"))
        self.addCleanup(bus.close)

    def fake_notify(self, body):
        command = self.root / "notify-send"
        command.write_text("#!/bin/sh\n" + body + "\n")
        command.chmod(0o755)

    def notify(self):
        result = subprocess.run(
            ["sh", str(NOTIFIER)], env=self.env, capture_output=True, timeout=5
        )
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b"")
        self.assertEqual(result.stderr, b"")

    def test_no_desktop_is_a_quiet_noop(self):
        self.fake_notify('touch "$CALLS"')
        self.notify()
        self.assertFalse(self.calls.exists())

    def test_ssh_uses_user_bus_and_keeps_generic_message(self):
        self.desktop()
        self.fake_notify('printf "%s\\n" "$DBUS_SESSION_BUS_ADDRESS" "$@" > "$CALLS"')
        self.notify()
        self.assertEqual(
            self.calls.read_text().splitlines(),
            [
                f"unix:path={self.runtime}/bus",
                "--app-name=Agent",
                "--icon=dialog-information",
                "Agent",
                "Agent needs attention",
            ],
        )

    def test_missing_service_and_stalled_delivery_do_not_fail_agent(self):
        self.desktop()
        self.fake_notify("exit 1")
        self.notify()
        self.fake_notify("sleep 10")
        start = time.monotonic()
        self.notify()
        self.assertLess(time.monotonic() - start, 4.5)


if __name__ == "__main__":
    unittest.main()
