extends TestCase
## A suite that is supposed to fail.
##
## It is **not** part of the normal run: `tests/run_tests.gd` only loads it when
## `GD_SELF_CHECK=1` is set, which only the `gate-self-check` job in
## `.github/workflows/ci.yml` does (and that job is manual-only).
##
## Its purpose is to prove the gate, not the code: if the workflow ever went green
## while a suite was failing, this canary would be the thing that noticed. The check
## below is deliberately false and must never be "fixed".

func test_a_failing_check_is_reported_as_a_failure() -> void:
	check_true(false, "this assertion is false on purpose: it exists to prove the gate fails")
