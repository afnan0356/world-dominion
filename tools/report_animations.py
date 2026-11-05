#!/usr/bin/env python3
"""Generate docs/ANIMATION.md from the animation table in the code.

The table is `AnimationTokens.CATALOGUE` in
`src/ui/animation/animation_tokens.gd`. This script is deliberately a *parser of
that file* rather than a second hand-written document: the documentation cannot say
"440 ms" while the code says 180, because the prose is produced from the code and
`--check` fails when the committed file is stale.

It also checks the opposite direction, which a document alone cannot: every
animation name used in `src/` must exist in the table, so a renamed or deleted
animation cannot leave a call site behind.

    python3 tools/report_animations.py            # rewrite docs/ANIMATION.md
    python3 tools/report_animations.py --check    # fail when it is stale
"""

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOKENS = ROOT / "src/ui/animation/animation_tokens.gd"
DOC = ROOT / "docs/ANIMATION.md"
SRC = ROOT / "src"
FIELDS = ("duration_ms", "easing", "trigger", "reduced", "flashes", "loop")
MAX_FLASHES = 3


def parse_catalogue() -> dict:
    text = TOKENS.read_text(encoding="utf-8")
    # Easing is declared as a named constant ("cubic out"), so the document shows the
    # human words rather than the identifier.
    constants = dict(re.findall(r'const (EASE_\w+) := "([^"]+)"', text))
    start = text.index("const CATALOGUE := {")
    body = text[start:]
    entries = {}
    current = None
    for line in body.splitlines()[1:]:
        stripped = line.strip()
        if current is None:
            match = re.match(r'^"(\w+)": \{$', stripped)
            if match:
                current = match.group(1)
                entries[current] = {}
            continue
        if stripped.startswith("},") or stripped == "}":
            current = None
            continue
        match = re.match(r'^"(\w+)": (.+?),$', stripped)
        if match:
            key, raw = match.group(1), match.group(2)
            if raw.startswith('"'):
                entries[current][key] = raw.strip('"')
            elif raw in constants:
                entries[current][key] = constants[raw]
            elif raw in ("true", "false"):
                entries[current][key] = raw == "true"
            else:
                entries[current][key] = float(raw)
    if not entries:
        raise SystemExit("no animation entries parsed from animation_tokens.gd")
    for name, entry in entries.items():
        missing = [field for field in FIELDS if field not in entry]
        if missing:
            raise SystemExit(f"{name}: missing {', '.join(missing)}")
        if float(entry["flashes"]) > 0:
            period = float(entry["duration_ms"]) / 1000.0
            per_second = float(entry["flashes"]) / period if period > 0 else 99
            if per_second > MAX_FLASHES:
                raise SystemExit(
                    f"{name}: {per_second:.2f} flashes per second exceeds the limit of {MAX_FLASHES}")
    return entries


def used_names() -> dict:
    """Every animation id mentioned at a call site, with the file it appears in."""
    pattern = re.compile(r'(?:Animations?Tokens\.duration_seconds|AnimationService\.play|'
                         r'_anim\.play|_anim\.play_method|_anim\.loop|'
                         r'_emphasise|AnimationTokens\.is_loop|'
                         r'AnimationTokens\.duration_seconds)\(\s*"([\w]+)"')
    found = {}
    for path in sorted(SRC.rglob("*.gd")):
        text = path.read_text(encoding="utf-8")
        for name in pattern.findall(text):
            found.setdefault(name, set()).add(str(path.relative_to(ROOT)))
    constants = re.compile(r'const ANIMATION := "([\w]+)"')
    for path in sorted(SRC.rglob("*.gd")):
        for name in constants.findall(path.read_text(encoding="utf-8")):
            found.setdefault(name, set()).add(str(path.relative_to(ROOT)))
    return found


def render(entries: dict) -> str:
    lines = [
        "# Animation",
        "",
        "Every moving thing in WORLD DOMINION, what starts it, and what happens instead",
        "when a player turns **Reduced motion** on. Written in plain language; the exact",
        "names below are the ones used in the code.",
        "",
        "> This file is **generated** from `AnimationTokens.CATALOGUE` by",
        "> `python3 tools/report_animations.py`. Do not hand-edit it: edit the table in",
        "> `src/ui/animation/animation_tokens.gd` and regenerate. CI runs",
        "> `--check` and fails if the two disagree.",
        "",
        "## How animation works here",
        "",
        "One small runner, `AnimationService`, does all of it. A screen creates one for",
        "itself, and every animation names an entry from the table below. Four rules",
        "come out of that design, and each one has a test:",
        "",
        "1. **Nothing blocks input.** The runner never accepts, swallows or waits for",
        "   input; it only changes values. A camera flight is cancelled by the first",
        "   drag, zoom or key press, so the player always wins.",
        "2. **Nothing animates when nothing changes.** Asking for a value the target",
        "   already has creates no tween at all, and a paused campaign runs no ambient",
        "   animation.",
        "3. **Every animation has a reduced-motion answer**, written in the table. Under",
        "   reduced motion the runner applies the final value immediately and creates no",
        "   tween; looping animations (the selection pulse, the ambient sea) do not start.",
        "4. **Nothing flashes more than three times per second.** The table declares a",
        "   flash rate per entry and the generator refuses to write a document that",
        "   breaks the limit; the suite checks the same rule.",
        "",
        "## The animations",
        "",
        "| Name | Duration | Easing | Starts when | With reduced motion |",
        "| --- | ---: | --- | --- | --- |",
    ]
    for name in sorted(entries):
        entry = entries[name]
        duration = float(entry["duration_ms"])
        if entry["loop"]:
            shown = f"{duration:.0f} ms per leg, repeating"
        else:
            shown = f"{duration:.0f} ms"
        lines.append(f"| `{name}` | {shown} | {entry['easing']} | {entry['trigger']} "
                     f"| {entry['reduced']} |")
    lines += [
        "",
        "## Where each one is used",
        "",
        "| Name | Call sites |",
        "| --- | --- |",
    ]
    usage = used_names()
    for name in sorted(entries):
        sites = usage.get(name, set())
        listed = ", ".join(f"`{site}`" for site in sorted(sites)) if sites else "not called yet"
        lines.append(f"| `{name}` | {listed} |")
    lines += [
        "",
        "## Ambient ocean motion",
        "",
        "The sea drifts very slowly — a few pixels of gradient over half a second — while",
        "the campaign clock is running. It is off when the clock is paused, off in reduced",
        "map detail, and off under reduced motion, so a still screen costs nothing: the map",
        "only redraws when something actually changed.",
        "",
        "## What is not animated",
        "",
        "Loading, saving, autosaving and the simulation itself never animate: they are",
        "work, not presentation, and pretending otherwise would hide their real cost. The",
        "developer overlay reports the truth instead.",
        "",
        "## Regenerating",
        "",
        "```bash",
        "python3 tools/report_animations.py            # rewrite this file",
        "python3 tools/report_animations.py --check    # fail when it is stale",
        "```",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    entries = parse_catalogue()
    usage = used_names()
    unknown = sorted(name for name in usage if name not in entries)
    if unknown:
        print("animations used in code but missing from the table:")
        for name in unknown:
            print(f"  {name} in {', '.join(sorted(usage[name]))}")
        return 1

    document = render(entries)
    if args.check:
        if not DOC.exists():
            print(f"{DOC.relative_to(ROOT)} is missing; run tools/report_animations.py")
            return 1
        if DOC.read_text(encoding="utf-8") != document:
            print(f"{DOC.relative_to(ROOT)} is stale; run tools/report_animations.py")
            return 1
        print(f"{DOC.relative_to(ROOT)} is up to date ({len(entries)} animations, "
              f"{len(usage)} used in code)")
        return 0
    DOC.parent.mkdir(parents=True, exist_ok=True)
    DOC.write_text(document, encoding="utf-8")
    print(f"wrote {DOC.relative_to(ROOT)}: {len(entries)} animations, "
          f"{len(usage)} used in code")
    return 0


if __name__ == "__main__":
    sys.exit(main())
