#!/usr/bin/env python3
"""Check that the data candidates in `docs/DATA_CANDIDATES.md` are still where that page says.

What this does — and deliberately does not do:

* it downloads **metadata only**: a repository's licence file, its README, or a dataset's
  `datapackage.json`;
* it never downloads a data file, and it imports nothing into the game;
* it verifies three things per candidate: the pinned commit still resolves, the licence file the
  document names still exists, and the wording the document quotes is still in the file.

Why bother: `docs/DATA_CANDIDATES.md` makes factual claims about other people's repositories. A
claim like "licence: CC0, stated in LICENSE.md" is only true while that file says so. This tool is
the check that stops a stale sentence becoming a licence problem in Milestone 12.

Usage:

    python3 tools/check_data_candidates.py            # check and report
    python3 tools/check_data_candidates.py --self-test
"""

from __future__ import annotations

import argparse
import base64
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.github.com"

# Every candidate is (repository, pinned commit, licence file, a phrase the licence file must
# still contain, a description of what the candidate is for).
CANDIDATES = [
    {
        "repo": "factbook/factbook.json",
        "commit": "144d6977b2b01ac1cbd220de754c0a005616760b",
        "licence_file": "LICENSE.md",
        "licence_phrase": "CC0 1.0 Universal",
        "purpose": "government type, current-year economy (archive of a discontinued publication)",
    },
    {
        "repo": "owid/energy-data",
        "commit": "f8de88a4f6f9cab44f1cf606047cbd6c4414042c",
        "licence_file": "README.md",
        "licence_phrase": "Creative Commons BY license",
        "purpose": "energy, electricity generation by fuel; population and Maddison GDP cross-check",
    },
    {
        "repo": "datasets/country-codes",
        "commit": "2d84034a0cae19ea5444b78c2131304a5c7f4bb9",
        "licence_file": "README.md",
        "licence_phrase": "Public Domain Dedication and License",
        "purpose": "FIPS to ISO join (mixed licence, recorded as a caveat)",
    },
    {
        "repo": "lukes/ISO-3166-Countries-with-Regional-Codes",
        "commit": "145f1ad3caff212ed25f42b0ee2c8b92a75af895",
        "licence_file": "LICENSE.md",
        "licence_phrase": "Creative Commons Attribution-ShareAlike 4.0",
        "purpose": "UN regions — verified and deliberately not used (share-alike)",
    },
    {
        "repo": "unicode-org/cldr",
        "commit": "f69257926c43f1cb22cf3fcd93e709a2ca994bb7",
        "licence_file": "LICENSE",
        "licence_phrase": "COPYRIGHT AND PERMISSION NOTICE",
        "purpose": "ISO 4217 currencies (already in use)",
    },
]

# Candidates the document records as blocked or unlicensed. They are checked for reachability
# only: the point is that they still exist and are still unusable, not that they are usable.
BLOCKED = [
    {
        "repo": "owid/owid-datasets",
        "commit": "6155d4ca1ea14ef30e753010a25521eeb416e8a2",
        "reason": "no licence statement in the repository; archived",
    },
]


class CheckError(RuntimeError):
    """A candidate could not be checked."""


def _get_json(url: str) -> dict:
    request = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(request, timeout=45) as response:  # noqa: S310 - fixed host
        return json.load(response)


def _file_text(repo: str, path: str, ref: str) -> str:
    url = f"{API}/repos/{repo}/contents/{urllib.parse.quote(path)}?ref={ref}"
    payload = _get_json(url)
    if payload.get("type") != "file":
        raise CheckError(f"{repo}: {path} is not a file")
    return base64.b64decode(payload["content"]).decode("utf-8", "replace")


def check_candidate(candidate: dict) -> tuple[bool, str]:
    repo = candidate["repo"]
    commit = candidate["commit"]
    try:
        _get_json(f"{API}/repos/{repo}")
    except urllib.error.HTTPError as error:
        return False, f"repository does not resolve ({error.code})"
    except OSError as error:
        return False, f"repository unreachable ({error})"
    try:
        _get_json(f"{API}/repos/{repo}/commits/{commit}")
    except urllib.error.HTTPError as error:
        return False, f"pinned commit does not resolve ({error.code})"
    except OSError as error:
        return False, f"commit unreachable ({error})"
    try:
        text = _file_text(repo, candidate["licence_file"], commit)
    except urllib.error.HTTPError as error:
        return False, f"{candidate['licence_file']} is missing ({error.code})"
    except OSError as error:
        return False, f"{candidate['licence_file']} unreachable ({error})"
    phrase = candidate["licence_phrase"]
    if phrase not in text:
        return False, (f"{candidate['licence_file']} no longer contains '{phrase}' — "
                       "the document must be corrected")
    return True, f"{candidate['licence_file']} at {commit[:7]} still says '{phrase}'"


def run() -> int:
    failures = 0
    print(f"{'candidate':48s} result")
    for candidate in CANDIDATES:
        ok, message = check_candidate(candidate)
        if not ok:
            failures += 1
        print(f"{candidate['repo']:48s} {'ok' if ok else 'FAIL'} — {message}")
        if ok:
            print(f"{'':48s}      {candidate['purpose']}")
    for blocked in BLOCKED:
        try:
            _get_json(f"{API}/repos/{blocked['repo']}/commits/{blocked['commit']}")
            print(f"{blocked['repo']:48s} ok — still present and still blocked: "
                  f"{blocked['reason']}")
        except (urllib.error.HTTPError, OSError) as error:
            failures += 1
            print(f"{blocked['repo']:48s} FAIL — {error}")
    print()
    if failures:
        print(f"{failures} candidate(s) need attention", file=sys.stderr)
        return 1
    print(f"{len(CANDIDATES)} verified candidates and {len(BLOCKED)} blocked candidate checked")
    return 0


def self_test() -> int:
    """The rules that keep the check honest, exercised without a network call."""
    if not CANDIDATES:
        print("self-test FAILED: no candidates")
        return 1
    for candidate in CANDIDATES:
        for key in ("repo", "commit", "licence_file", "licence_phrase", "purpose"):
            if not str(candidate.get(key, "")).strip():
                print(f"self-test FAILED: {candidate.get('repo', '?')} has no {key}")
                return 1
        if len(candidate["commit"]) != 40:
            print(f"self-test FAILED: {candidate['repo']} is not pinned to a full commit")
            return 1
    for blocked in BLOCKED:
        if len(blocked["commit"]) != 40 or not blocked["reason"]:
            print(f"self-test FAILED: blocked candidate {blocked.get('repo')} is incomplete")
            return 1
    print(f"self-test ok: {len(CANDIDATES)} candidates and {len(BLOCKED)} blocked, "
          "all pinned to full commits")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true",
                        help="check the tool's own rules without a network call")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    try:
        return run()
    except CheckError as error:
        print(f"candidate check failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
