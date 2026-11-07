#!/usr/bin/env python3
"""Generate `docs/INDEX.md`, and keep the documentation set honest.

The index is generated from an explicit table, not from whatever happens to be in the
folder: a document that is not in the table is an error, so nothing can exist without
someone deciding what it is for. Each row says what the document is, who it is for, and
whether it is written by hand or generated.

`--check` also fails on a **dead relative link** in any committed Markdown file, which is
the failure mode that makes documentation useless: a page that points at a page that no
longer exists.

Usage:

    python3 tools/build_docs_index.py            # rewrite docs/INDEX.md
    python3 tools/build_docs_index.py --check    # fail when it is stale or a link is dead
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
INDEX = DOCS / "INDEX.md"

WRITTEN = "written by hand"
GENERATED = "generated — CI checks it"

# Every document, with the one sentence a reader needs before opening it. `path` is
# relative to the repository root. Adding a document without adding a row here fails.
DOCUMENTS = (
    ("README.md", "The front door: what this is, how to run it, where everything lives.",
     WRITTEN),
    ("ROADMAP.md", "The plan, milestone by milestone, with what is done and what is not.",
     WRITTEN),
    ("CONTRIBUTING.md", "The rules a change must follow, and the order the pipeline runs in.",
     WRITTEN),
    ("ARCHITECTURE.md", "How the code is organised, and why the layers are separate.",
     WRITTEN),
    ("DESIGN_SYSTEM.md", "Tokens, theme variations and the sizes every control uses.",
     WRITTEN),
    ("GAME_DESIGN.md", "The game's systems as designed: economy, diplomacy, time.",
     WRITTEN),
    ("THIRD_PARTY_LICENSES.md", "Every third-party thing shipped or derived from, with its "
     "licence text.", WRITTEN),
    ("docs/INDEX.md", "This page: what every document is for.", GENERATED),
    ("docs/WALKTHROUGH.md", "What a player can actually do in the current build, screen by "
     "screen.", WRITTEN),
    ("docs/OWNER_GUIDE.md", "The runbook for a one-person project: data updates, builds, "
     "hotfixes, backups.", WRITTEN),
    ("docs/GAME_VISION.md", "Why the game exists and what it refuses to become.",
     WRITTEN),
    ("docs/GLOSSARY.md", "The words this project uses, defined once.", WRITTEN),
    ("docs/SECURITY.md", "Save integrity, what is trusted, what is checked, what is "
     "refused.", WRITTEN),
    ("docs/SAVE_FORMAT.md", "Every field in a save, its type and what changes it.",
     WRITTEN),
    ("docs/SIMULATION_CORE.md", "The simulation's rules and its determinism guarantees.",
     WRITTEN),
    ("docs/PROGRESSION.md", "XP, levels, VIP and speed, with the curve's numbers.",
     GENERATED),
    ("docs/START_NATIONS.md", "Which records can begin a campaign, and why the rest cannot.",
     WRITTEN),
    ("docs/PERFORMANCE.md", "Measured load, frame and save costs, and the budgets.",
     WRITTEN),
    ("docs/ANIMATION.md", "Every animated thing, its duration and its reduced-motion "
     "behaviour.", WRITTEN),
    ("docs/CONTROL_SIZES.md", "Every control's declared size, and the exceptions with their "
     "reasons.", GENERATED),
    ("docs/MAP_RENDERING.md", "How the atlas is drawn, and the cost of each layer.",
     WRITTEN),
    ("docs/ANDROID.md", "The target platform's constraints and what is still unverified.",
     WRITTEN),
    ("docs/UI_REFERENCE_NOTES.md", "What the interface's reference material informed, and what "
     "was refused; records that the files could not be read in this environment.",
     WRITTEN),
    ("docs/EVENT_LOG.md", "The campaign's event log, the two screens that read it, and the "
     "schema 3 → 4 migration.", WRITTEN),
    ("docs/research/README.md", "What a research note is, and what CONSULTED, UNVERIFIED and "
     "NOT AVAILABLE each require.", WRITTEN),
    ("docs/FEATURE_INVENTORY.md", "Every feature the brief asks for, its MVP / LATER / REJECTED "
     "call, and the decisions only the owner can make.", WRITTEN),
    ("docs/SCREEN_MAP.md", "Every screen, where a player reaches it from, which milestone builds "
     "it and what data it needs.", WRITTEN),
    ("docs/DATA_CANDIDATES.md", "What data the next systems need, what could be verified here, "
     "what is blocked by a licence and what is still missing.", WRITTEN),
    ("docs/research/RESOURCES.md", "Could resources and energy be modelled without inventing "
     "numbers? What to check first, and what is unknown.", WRITTEN),
    ("docs/research/POLITICS.md", "Could politics and relations be modelled without taking a "
     "side? The neutrality problem, stated.", WRITTEN),
    ("docs/BUILD.md", "The two build paths, what each produces, and how an export failure is "
     "reported.", WRITTEN),
    ("docs/OPEN_ENDED_DESIGN.md", "Open questions, deliberately unanswered, kept out of the "
     "build.", WRITTEN),
    ("docs/MANUAL_TEST_CHECKLIST.md", "What a person should try by hand before a release.",
     WRITTEN),
    ("docs/PR_REVIEW_GUIDE.md", "How a change here is reviewed — by the owner, against "
     "this list.", WRITTEN),
    ("docs/WHAT_IS_NEW.md", "The What is new screen's rules: one card per change, the files "
     "that make each line true, and the section about what is missing.", WRITTEN),
    ("docs/DATA_SOURCES.md", "Every dataset, its pin, its licence and what was rejected.",
     WRITTEN),
    ("docs/DATA_SCHEMA.md", "The shape of every data file the game loads.", WRITTEN),
    ("docs/DATA_COMPLETENESS.md", "Which records have which sections, and which do not.",
     GENERATED),
    ("docs/DATA_QUALITY.md", "The atlas's geometry quality: repairs, drops and counts.",
     GENERATED),
    ("docs/COUNTRY_FOLDER_GUIDE.md", "How to read one country's folder, with a worked "
     "example.", WRITTEN),
    ("docs/COUNTRY_CODES_AND_REGIONS.md", "The codes and picker groups, and what is not "
     "official.", GENERATED),
    ("docs/DISPUTED_TERRITORIES.md", "Every disputed or dependent unit, and the position "
     "taken (none).", WRITTEN),
    ("docs/STATISTICS_DESIGN.md", "What the statistics are for, and what they are not.",
     WRITTEN),
    ("docs/STATISTICS_REPORT.md", "The statistics source, its matching and every rejected "
     "value.", GENERATED),
    ("docs/CURRENCY_REPORT.md", "The currency source, its matching and every unmatched "
     "record.", GENERATED),
    ("docs/evidence/README.md", "What evidence could and could not be captured here, and "
     "why.", WRITTEN),
    ("docs/layout-diagrams/README.md", "Why these are diagrams and not screenshots, and how "
     "they were made.", WRITTEN),
    ("docs/layout-diagrams/country-picker.md", "The country picker's layout at each size.",
     WRITTEN),
    ("docs/layout-diagrams/first-run-screen.md", "The first-run screens' layouts.", WRITTEN),
    ("docs/layout-diagrams/profile-screen.md", "The profile screen's layout at each size.",
     WRITTEN),
    ("docs/layout-diagrams/tutorial.md", "The tutorial panel's layout.", WRITTEN),
    ("docs/layout-diagrams/diagnostics.md", "The diagnostics screen's layout at each "
     "supported size.", WRITTEN),
    ("docs/layout-diagrams/help-roadmap.md", "The Help and Roadmap screens' layouts.",
     WRITTEN),
    ("docs/layout-diagrams/recovery-screens.md", "The worlds, backup and deletion layouts.",
     WRITTEN),
    ("docs/layout-diagrams/what-is-new.md", "The What is new screen's layout at desktop and "
     "at 640x360.", WRITTEN),
)

# Sections the index groups rows into, in reading order, with the question each answers.
SECTIONS = (
    ("Start here", "What is this, and how do I change it?",
     ("README.md", "ROADMAP.md", "CONTRIBUTING.md", "ARCHITECTURE.md", "docs/INDEX.md",
      "docs/OWNER_GUIDE.md")),
    ("Playing and reviewing the build", "What works today, and how to check it?",
     ("docs/WALKTHROUGH.md", "docs/MANUAL_TEST_CHECKLIST.md", "docs/PR_REVIEW_GUIDE.md",
      "docs/GAME_VISION.md", "docs/GLOSSARY.md", "docs/OPEN_ENDED_DESIGN.md",
      "docs/WHAT_IS_NEW.md", "docs/evidence/README.md")),
    ("Design and rules", "What are the game's systems and their guarantees?",
     ("GAME_DESIGN.md", "DESIGN_SYSTEM.md", "docs/SIMULATION_CORE.md",
      "docs/PROGRESSION.md", "docs/START_NATIONS.md", "docs/SECURITY.md",
      "docs/SAVE_FORMAT.md")),
    ("The world data", "Where do the numbers and the map come from?",
     ("docs/DATA_SOURCES.md", "docs/DATA_SCHEMA.md", "docs/COUNTRY_FOLDER_GUIDE.md",
      "docs/DATA_COMPLETENESS.md", "docs/DATA_QUALITY.md", "docs/STATISTICS_DESIGN.md",
      "docs/STATISTICS_REPORT.md", "docs/CURRENCY_REPORT.md",
      "docs/COUNTRY_CODES_AND_REGIONS.md", "docs/DISPUTED_TERRITORIES.md")),
    ("The engine and the platform", "How is it built and drawn, and what does it cost?",
     ("docs/research/README.md", "docs/research/RESOURCES.md", "docs/research/POLITICS.md",
      "docs/MAP_RENDERING.md", "docs/PERFORMANCE.md", "docs/ANIMATION.md",
      "docs/CONTROL_SIZES.md", "docs/ANDROID.md", "docs/BUILD.md")),
    ("Layouts", "What does each screen look like at each size?",
     ("docs/layout-diagrams/README.md", "docs/layout-diagrams/country-picker.md",
      "docs/layout-diagrams/first-run-screen.md", "docs/layout-diagrams/profile-screen.md",
      "docs/layout-diagrams/tutorial.md", "docs/layout-diagrams/diagnostics.md",
      "docs/layout-diagrams/help-roadmap.md", "docs/layout-diagrams/recovery-screens.md",
      "docs/layout-diagrams/what-is-new.md")),
    ("Legal", "What is shipped from someone else?", ("THIRD_PARTY_LICENSES.md",)),
)

LINK_PATTERN = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
SKIP_PREFIXES = ("http://", "https://", "mailto:", "#")
GENERATED_BY = {
    "docs/PROGRESSION.md": "tools/build_progression_doc.py",
    "docs/CONTROL_SIZES.md": "tools/control_size_report.py",
    "docs/DATA_COMPLETENESS.md": "tools/report_data_completeness.py",
    "docs/DATA_QUALITY.md": "tools/build_world_atlas.py --report",
    "docs/COUNTRY_CODES_AND_REGIONS.md": "tools/build_country_codes.py",
    "docs/STATISTICS_REPORT.md": "tools/build_statistics.py --report",
    "docs/CURRENCY_REPORT.md": "tools/build_currency.py --report",
    "docs/INDEX.md": "tools/build_docs_index.py",
}


def markdown_files() -> list[str]:
    """Every committed Markdown file that the index and the link check cover."""
    found: list[str] = []
    for path in sorted(ROOT.glob("*.md")):
        if path.name != "docs":
            found.append(path.name)
    for path in sorted(DOCS.rglob("*.md")):
        found.append(str(path.relative_to(ROOT)))
    return found


def document() -> str:
    rows = {path: (purpose, kind) for path, purpose, kind in DOCUMENTS}
    listed = {path for path, _, _ in DOCUMENTS}
    grouped: set[str] = set()
    lines: list[str] = []
    add = lines.append
    add("# Documentation index")
    add("")
    add("**Generated by `tools/build_docs_index.py`. Do not edit by hand: CI regenerates it "
        "and fails if the committed copy differs.**")
    add("")
    add("Every document in this repository, what it is for, and whether a person or a tool "
        "wrote it. A document that is not on this page fails the build, so nothing here "
        "can be forgotten.")
    add("")
    for title, question, paths in SECTIONS:
        add(f"## {title}")
        add("")
        add(f"*{question}*")
        add("")
        add("| Document | What it is | Written by |")
        add("| --- | --- | --- |")
        for path in paths:
            if path not in rows:
                continue
            purpose, kind = rows[path]
            name = Path(path).name
            add(f"| [{name}]({os.path.relpath(ROOT / path, DOCS).replace(os.sep, '/')}) "
                f"| {purpose} | {kind} |")
            grouped.add(path)
        add("")
    missing = [path for path in rows if path not in grouped]
    if missing:
        add("## Not yet grouped")
        add("")
        for path in missing:
            add(f"* `{path}`")
        add("")
    add("## Generated documents")
    add("")
    add("These are rebuilt from the repository by the tool named, and CI fails if the "
        "committed copy is stale. They are the only documents that must never be edited by "
        "hand.")
    add("")
    add("| Document | Regenerate with |")
    add("| --- | --- |")
    for path, tool in GENERATED_BY.items():
        add(f"| `{path}` | `python3 {tool}` |")
    add("")
    return "\n".join(lines)


def check_index() -> list[str]:
    problems: list[str] = []
    wanted = document()
    if not INDEX.exists():
        problems.append("docs/INDEX.md is missing")
    elif INDEX.read_text(encoding="utf-8") != wanted:
        problems.append("docs/INDEX.md is stale (run python3 tools/build_docs_index.py)")
    listed = {path for path, _, _ in DOCUMENTS}
    for path in markdown_files():
        if path not in listed:
            problems.append(f"{path} is not in the documentation index; add a row for it")
    for path, _, kind in DOCUMENTS:
        if not (ROOT / path).exists():
            problems.append(f"{path} is listed in the index but does not exist")
        elif kind == GENERATED and path not in GENERATED_BY:
            problems.append(f"{path} claims to be generated but names no tool")
    return problems


def check_links() -> list[str]:
    problems: list[str] = []
    for path in markdown_files():
        text = (ROOT / path).read_text(encoding="utf-8", errors="replace")
        base = (ROOT / path).parent
        for target in LINK_PATTERN.findall(text):
            if target.startswith(SKIP_PREFIXES) or "://" in target:
                continue
            clean = target.split("#")[0].strip()
            if not clean:
                continue
            resolved = (base / clean).resolve()
            try:
                exists = resolved.exists()
            except OSError:
                exists = False
            if not exists:
                problems.append(f"{path}: the link to {target!r} points at nothing")
    return problems


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__ or "")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    if args.check:
        problems = check_index() + check_links()
        for problem in problems:
            print(f"docs: {problem}")
        if problems:
            print(f"documentation is out of date: {len(problems)} problem(s)")
            return 1
        print(f"documentation ok: {len(DOCUMENTS)} documents indexed, no dead links")
        return 0
    INDEX.write_text(document(), encoding="utf-8", newline="\n")
    print(f"wrote docs/INDEX.md ({len(DOCUMENTS)} documents)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
