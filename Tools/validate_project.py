"""Check literal shipped resource references without requiring an editor session."""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
folders = ("Scence", "Characters", "Combat", "UI", "Weapons", "Story", "Art", "Tests")
sources = [root / "project.godot"]
for folder in folders:
    sources.extend(p for p in (root / folder).rglob("*") if p.suffix in (".gd", ".tscn", ".tres", ".json", ".gdshader"))
errors = []
references = 0
for source in sources:
    for relative in re.findall(r'''["']res://([^"'\r\n]+)["']''', source.read_text(encoding="utf-8-sig")):
        if any(token in relative for token in ("%", "{", "}")) or relative.startswith(".godot/"):
            continue
        if not Path(relative).suffix:  # Runtime path prefixes, not concrete resources.
            continue
        if source.name == "portal_smoke.gd" and relative == "Scence/future_room.tscn":
            continue  # Deliberate nonexistent destination tests portal signal payload only.
        references += 1
        if not (root / relative).exists():
            errors.append(f"{source.relative_to(root).as_posix()} -> {relative}")
print(f"Checked {len(sources)} files and {references} literal resource references.")
for error in errors:
    print("MISSING:", error)
sys.exit(bool(errors))
