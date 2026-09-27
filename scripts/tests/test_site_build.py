"""The Pages artifact must contain only the intended public demo files."""

import importlib.util
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("build_site", ROOT / "scripts" / "build-site.py")
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


class SiteBuildTests(unittest.TestCase):
    def test_only_allowlisted_files_are_published(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "site").mkdir()
            (root / "presets").mkdir()
            for name in BUILDER.SITE_FILES:
                (root / "site" / name).write_text("demo", encoding="utf-8")
            (root / "presets" / "all.json").write_text('{"profiles": []}', encoding="utf-8")
            (root / "site" / ".env").write_text("synthetic-private-config", encoding="utf-8")
            (root / "site" / "README.md").write_text("maintainer instructions", encoding="utf-8")
            output = root / "output"
            BUILDER.build_site(root, output)
            self.assertEqual({path.name for path in output.iterdir()}, BUILDER.OUTPUT_FILES)
            self.assertEqual((output / "presets.json").read_bytes(), (root / "presets" / "all.json").read_bytes())
            BUILDER.build_site(root, output)

    def test_rejects_unexpected_existing_output(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            private = output / ".env"
            private.write_text("synthetic-private-config", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Unexpected output entry"):
                BUILDER.build_site(ROOT, output)
            self.assertEqual(private.read_text(encoding="utf-8"), "synthetic-private-config")

    def test_rejects_output_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "target"
            target.mkdir()
            output = root / "output"
            output.symlink_to(target, target_is_directory=True)
            with self.assertRaisesRegex(ValueError, "symbolic link"):
                BUILDER.build_site(ROOT, output)
            self.assertEqual(list(target.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
