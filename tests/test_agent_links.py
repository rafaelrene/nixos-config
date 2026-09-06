import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "agent_links", ROOT / "modules/development/agents/agent-links.py"
)
agent_links = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(agent_links)


class AgentLinksTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.home = self.root / "home"
        self.source = self.root / "source"
        self.home.mkdir()
        self.source.mkdir()
        self.dirs = [
            ".local/share/codex/skills",
            ".local/share/claude/skills",
            ".config/opencode/skills",
        ]
        self.manifest = {
            "links": {},
            "skillDirectories": self.dirs,
            "previousSettings": {},
        }

    def add_skill(self, name):
        skill = self.source / "skills" / name
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text(name)
        for directory in self.dirs:
            self.manifest["links"][f"{directory}/{name}"] = f"skills/{name}"

    def activate(self):
        agent_links.reconcile(self.home, self.source, self.manifest)

    def test_skill_lifecycle_preserves_unmanaged_entries_and_writes_to_source(self):
        self.add_skill("first")
        self.activate()
        codex = self.home / self.dirs[0]
        (codex / ".system").mkdir()
        (codex / ".system/builtin").write_text("keep")
        (codex / "personal").mkdir()
        (codex / "external").symlink_to(self.root / "unavailable-external")
        (codex / "first/SKILL.md").write_text("edited through Codex")
        self.assertEqual(
            (self.source / "skills/first/SKILL.md").read_text(), "edited through Codex"
        )
        self.activate()
        self.add_skill("second")
        for directory in self.dirs:
            del self.manifest["links"][f"{directory}/first"]
        self.activate()
        for directory in self.dirs:
            self.assertFalse((self.home / directory / "first").is_symlink())
            self.assertEqual(
                (self.home / directory / "second").resolve(),
                self.source / "skills/second",
            )
        self.assertEqual((codex / ".system/builtin").read_text(), "keep")
        self.assertTrue((codex / "personal").is_dir())
        self.assertTrue((codex / "external").is_symlink())

    def test_initial_settings_are_backed_up_once_and_newer_edits_conflict(self):
        dest = self.home / ".local/share/claude/settings.json"
        dest.parent.mkdir(parents=True)
        original = b'{"theme":"dark"}\n'
        dest.write_bytes(original)
        (self.source / "settings.json").write_text('{"theme":"dark","hooks":{}}')
        relative = str(dest.relative_to(self.home))
        self.manifest["links"][relative] = "settings.json"
        self.manifest["previousSettings"][relative] = hashlib.sha256(
            original
        ).hexdigest()
        dest.write_text("newer settings")
        with self.assertRaisesRegex(ValueError, "conflicting path"):
            self.activate()
        self.assertEqual(dest.read_text(), "newer settings")
        dest.write_bytes(original)
        self.activate()
        self.activate()
        backups = list(
            (self.home / ".local/state/agent-config-backups").glob(
                "initial-*/.local/share/claude/settings.json"
            )
        )
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_bytes(), original)
        dest.write_text("updated settings")
        self.assertEqual(
            (self.source / "settings.json").read_text(), "updated settings"
        )

    def test_conflicts_and_missing_sources_prevent_partial_activation(self):
        self.add_skill("first")
        self.add_skill("second")
        conflict = self.home / self.dirs[-1] / "second"
        conflict.parent.mkdir(parents=True)
        conflict.symlink_to(self.root / "someone-elses-skill")
        with self.assertRaisesRegex(ValueError, "Unmanaged link"):
            self.activate()
        self.assertFalse((self.home / self.dirs[0] / "first").exists())
        self.assertTrue(conflict.is_symlink())
        conflict.unlink()
        (self.source / "skills/first/SKILL.md").unlink()
        (self.source / "skills/first").rmdir()
        with self.assertRaisesRegex(ValueError, "Missing source"):
            self.activate()
        self.assertFalse((self.home / self.dirs[0] / "second").exists())

    def test_empty_manifest_prunes_only_owned_links_and_rejects_linked_directories(
        self,
    ):
        self.add_skill("first")
        self.activate()
        self.manifest["links"] = {}
        (self.source / "skills/first/SKILL.md").unlink()
        (self.source / "skills/first").rmdir()
        self.activate()
        for directory in self.dirs:
            self.assertFalse((self.home / directory / "first").is_symlink())
        codex = self.home / self.dirs[0]
        codex.rmdir()
        codex.symlink_to(self.source / "skills")
        with self.assertRaisesRegex(ValueError, "real directory"):
            self.activate()


if __name__ == "__main__":
    unittest.main()
