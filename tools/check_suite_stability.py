#!/usr/bin/env python3
"""Compare headless-suite runs made in different orders, and fail on any disagreement.

Milestone 11 had a red run whose assertions passed in the next run with the same production
code. A single run cannot tell "this suite depends on what ran before it" from "this code is
right", so the suite is now run three times in CI — once in declaration order and twice in
shuffled order with fixed seeds — and this tool compares what came out.

It reads the runner's stdout and reduces each run to one line per suite::

    test_dossier\t9\t41208\tPASS

plus a total line. Two runs agree when every suite has the same verdict **and** the same
attempt count and assertion count; anything else is reported as a difference with the suite
named, and the exit status is 1. Assertion counts are compared because a suite that quietly
asserts less (a loop over an empty list, a fixture that failed to load) still "passes".

Usage::

    python3 tools/check_suite_stability.py normal.log shuffle-1.log shuffle-2.log
    python3 tools/check_suite_stability.py --self-test

The self-test proves the comparison fails on a changed verdict, a changed assertion count and a
missing suite, so the gate cannot become a rubber stamp.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

#: `PASS  test_dossier                9 tests · 29107 assertions`
LINE = re.compile(r"^(PASS|FAIL)\s+(\S+)\s+(\d+) tests ·\s*(\d+) assertions\s*$")
TOTAL = re.compile(r"^Assertions: (\d+) · Failures: (\d+)\s*$")
RESULT = re.compile(r"^RESULT: (PASS|FAIL)\s*$")
ORDER = re.compile(r"^ORDER (\w+) seed=(-?\d+) suites=(\d+)\s*$")


class CheckError(RuntimeError):
    """A run could not be read, or a claim about it was false."""


def parse(text: str) -> dict:
    """Reduce one run's output to {suite: (tests, assertions, verdict)} plus the totals."""
    suites: dict[str, tuple[int, int, str]] = {}
    total: tuple[int, int] | None = None
    result: str | None = None
    order: tuple[str, int, int] | None = None
    for line in text.splitlines():
        stripped = line.strip()
        match = LINE.match(stripped)
        if match:
            verdict, name, tests, assertions = match.groups()
            suites[name] = (int(tests), int(assertions), verdict)
            continue
        match = TOTAL.match(stripped)
        if match:
            total = (int(match.group(1)), int(match.group(2)))
            continue
        match = RESULT.match(stripped)
        if match:
            result = match.group(1)
            continue
        match = ORDER.match(stripped)
        if match:
            order = (match.group(1), int(match.group(2)), int(match.group(3)))
    if not suites:
        raise CheckError("the log contains no suite results; is it a test-runner log?")
    if result is None:
        raise CheckError("the log has no RESULT line")
    if order is None:
        # Older logs predate the ORDER line; treat them as the normal-order run.
        order = ("normal", 0, len(suites))
    return {"suites": suites, "total": total, "result": result, "order": order}


def differences(first: dict, other: dict) -> list[str]:
    """Everything that disagrees between two parsed runs, in the order a reader wants it."""
    problems: list[str] = []
    if first["result"] != other["result"]:
        problems.append(f"result differs: {first['result']} vs {other['result']}")
    a = first["suites"]
    b = other["suites"]
    for name in sorted(set(a) - set(b)):
        problems.append(f"suite missing from the second run: {name}")
    for name in sorted(set(b) - set(a)):
        problems.append(f"suite only in the second run: {name}")
    for name in sorted(set(a) & set(b)):
        tests_a, assertions_a, verdict_a = a[name]
        tests_b, assertions_b, verdict_b = b[name]
        if verdict_a != verdict_b:
            problems.append(f"{name}: {verdict_a} vs {verdict_b}")
        if assertions_a != assertions_b:
            problems.append(
                f"{name}: {assertions_a} assertions vs {assertions_b} — a suite that asserts a"
                " different amount in a different order depends on the order"
            )
        if tests_a != tests_b:
            problems.append(f"{name}: {tests_a} tests vs {tests_b}")
    if first["total"] != other["total"]:
        problems.append(f"totals differ: {first['total']} vs {other['total']}")
    return problems


def describe(run: dict) -> str:
    order, seed, count = run["order"]
    total = run["total"] or (0, 0)
    return (f"{order} order, seed {seed}: {count} suites, {total[0]} assertions, "
            f"result {run['result']}")


def compare(paths: list[Path]) -> int:
    runs = []
    for path in paths:
        text = path.read_text(errors="replace")
        runs.append((path, parse(text)))
    print("compared runs:")
    for path, run in runs:
        print(f"  {path.name}: {describe(run)}")
    failed = 0
    for index in range(1, len(runs)):
        problems = differences(runs[0][1], runs[index][1])
        label = f"{runs[0][0].name} vs {runs[index][0].name}"
        if problems:
            failed += 1
            print(f"DIFFERENT {label}:")
            for problem in problems:
                print(f"  - {problem}")
        else:
            print(f"identical {label}")
    if failed:
        print(f"suite stability: {failed} run(s) differ from the normal-order run")
        return 1
    print("suite stability ok: every order gives the same verdicts and assertion counts")
    return 0


NORMAL_LOG = """WORLD DOMINION · headless test suite
ORDER normal seed=0 suites=3
SUITE res://tests/suites/test_alpha.gd
  RUN test_one
PASS  test_alpha                 2 tests ·  10 assertions
SUITE res://tests/suites/test_beta.gd
PASS  test_beta                  1 tests ·   4 assertions
SUITE res://tests/suites/test_gamma.gd
PASS  test_gamma                 3 tests ·   7 assertions
-----------------------------------
Assertions: 21 · Failures: 0
RESULT: PASS
"""

SHUFFLED_LOG = NORMAL_LOG.replace("ORDER normal seed=0", "ORDER shuffle seed=17").replace(
    "PASS  test_gamma                 3 tests ·   7 assertions",
    "PASS  test_gamma                 3 tests ·   7 assertions")


def _expect_failure(name: str, body: str) -> str | None:
    path_a = Path("/tmp/stability-a.log")
    path_b = Path("/tmp/stability-b.log")
    path_a.write_text(NORMAL_LOG)
    path_b.write_text(body)
    import contextlib
    import io

    stream = io.StringIO()
    with contextlib.redirect_stdout(stream):
        status = compare([path_a, path_b])
    return None if status != 0 else f"the self-test case '{name}' was not detected"


def self_test() -> int:
    problems: list[str] = []
    normal = parse(NORMAL_LOG)
    shuffled = parse(SHUFFLED_LOG)
    if normal["order"][0] != "normal" or shuffled["order"][0] != "shuffle":
        problems.append("the ORDER line is not read")
    if differences(normal, shuffled):
        problems.append("a reordering with identical results was reported as a difference")
    if not differences(normal, parse(NORMAL_LOG.replace("PASS  test_beta ", "FAIL  test_beta "))):
        problems.append("a flipped verdict was not detected")
    if not differences(normal, parse(NORMAL_LOG.replace("4 assertions", "5 assertions"))):
        problems.append("a changed assertion count was not detected")
    if not differences(normal, parse(NORMAL_LOG.replace(
            "PASS  test_gamma                 3 tests ·   7 assertions\n", ""))):
        problems.append("a missing suite was not detected")
    if not differences(normal, parse(NORMAL_LOG.replace("RESULT: PASS", "RESULT: FAIL"))):
        problems.append("a changed total result was not detected")
    for name, body in (
        ("flipped verdict", NORMAL_LOG.replace("PASS  test_beta ", "FAIL  test_beta ")),
        ("changed count", NORMAL_LOG.replace("4 assertions", "5 assertions")),
    ):
        if _expect_failure(name, body):
            problems.append(_expect_failure(name, body) or "")
    try:
        parse("nothing here")
    except CheckError:
        pass
    else:
        problems.append("a log with no suite results was accepted")
    if problems:
        for problem in problems:
            print(f"self-test failure: {problem}")
        print("self-test failed")
        return 1
    print("self-test ok: every difference shape is detected, identical runs are not")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("logs", nargs="*", type=Path, help="suite logs, normal order first")
    parser.add_argument("--self-test", action="store_true", help="prove the comparison works")
    args = parser.parse_args(argv)
    try:
        if args.self_test:
            return self_test()
        if len(args.logs) < 2:
            parser.error("give at least two logs: the normal-order run first")
        for path in args.logs:
            if not path.exists():
                raise CheckError(f"{path} does not exist")
        return compare(args.logs)
    except CheckError as error:
        print(f"suite stability: {error}")
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
