#!/usr/bin/env bash
#
# mayhem/test.sh — RUN rosc's OWN upstream test suite (unit + integration tests + bench
# targets, prebuilt by mayhem/build.sh via `cargo test --no-run`). Asserts behavior:
# the suite is upstream's real assertion tests (decode/encode round-trips, address
# matching, type known-answer checks). Emits a CTRF summary; exits non-zero iff failed>0.
#
# Doc tests are SKIPPED (8 upstream doc examples): they require recompilation at run
# time, and test.sh must not compile. They are counted as skipped in the CTRF summary.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

MANIFEST="$SRC/mayhem/test-bins.txt"
DOC_TESTS_SKIPPED=8   # upstream doc examples; need rustc at run time — not run here

[ -s "$MANIFEST" ] || { echo "ERROR: $MANIFEST missing — build.sh should have built the test suite" >&2; emit_ctrf cargo-test 0 1; exit 1; }

total_passed=0; total_failed=0; total_ignored=0
while IFS= read -r bin; do
  [ -x "$bin" ] || { echo "ERROR: test binary $bin missing/not executable" >&2; total_failed=$(( total_failed + 1 )); continue; }
  echo "--- running $bin ---"
  out="$("$bin" 2>&1)"; rc=$?
  printf '%s\n' "$out"
  # libtest summary: "test result: ok. P passed; F failed; I ignored; M measured; ..."
  line="$(printf '%s\n' "$out" | grep -E '^test result:' | tail -1)"
  if [ -z "$line" ]; then
    echo "ERROR: $bin produced no libtest summary (rc=$rc) — counting as a failure" >&2
    total_failed=$(( total_failed + 1 ))
    continue
  fi
  p="$(printf '%s' "$line" | sed -nE 's/.* ([0-9]+) passed.*/\1/p')"
  f="$(printf '%s' "$line" | sed -nE 's/.* ([0-9]+) failed.*/\1/p')"
  i="$(printf '%s' "$line" | sed -nE 's/.* ([0-9]+) ignored.*/\1/p')"
  total_passed=$(( total_passed + ${p:-0} ))
  total_failed=$(( total_failed + ${f:-0} ))
  total_ignored=$(( total_ignored + ${i:-0} ))
  if [ "$rc" -ne 0 ] && [ "${f:-0}" -eq 0 ]; then total_failed=$(( total_failed + 1 )); fi
done < "$MANIFEST"

emit_ctrf cargo-test "$total_passed" "$total_failed" $(( total_ignored + DOC_TESTS_SKIPPED ))
