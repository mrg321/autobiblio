#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly ROBOT="$SCRIPT_DIR/.venv/bin/robot"
readonly PANDOC="$SCRIPT_DIR/.venv/bin/pandoc"
readonly REPORT_DIR="$SCRIPT_DIR/results/robot-reports"
readonly SUITES=(
    book-borrow.robot
    transform-book.robot
    pdf-to-text.robot
    text-to-epub.robot
    send-to-kindle.robot
)

fail() {
    echo "$*" >&2
    exit 1
}

[[ -x "$ROBOT" ]] || fail "Robot Framework executable not found: $ROBOT. Run setup.sh first."
[[ -x "$PANDOC" ]] || fail "Pandoc executable not found: $PANDOC. Run setup.sh first."
"$PANDOC" --version >/dev/null 2>&1 || fail "Pandoc executable could not be run: $PANDOC"

for suite in "${SUITES[@]}"; do
    [[ -f "$SCRIPT_DIR/$suite" ]] || fail "Robot suite not found: $suite"
done

mkdir -p "$REPORT_DIR"
export PYPANDOC_PANDOC="$PANDOC"
export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-0}"

declare -a statuses=()
declare -a exit_codes=()
declare -a durations=()
first_failure=0

cd "$SCRIPT_DIR"
for suite in "${SUITES[@]}"; do
    suite_name="${suite%.robot}"
    echo
    echo "=== Running $suite ==="
    start_seconds=$SECONDS

    "$ROBOT" \
        --outputdir "$REPORT_DIR" \
        --output "$suite_name-output.xml" \
        --log "$suite_name-log.html" \
        --report "$suite_name-report.html" \
        --removekeywords 'name:Fill Text' \
        --variable 'HEADLESS:True' \
        "$suite"
    exit_code=$?
    duration=$((SECONDS - start_seconds))

    if (( exit_code == 0 )); then
        status=PASS
    else
        status=FAIL
        if (( first_failure == 0 )); then
            first_failure=$exit_code
        fi
    fi

    statuses+=("$status")
    exit_codes+=("$exit_code")
    durations+=("$duration")
    printf '%s: %s (exit code %s, %ss)\n' "$status" "$suite" "$exit_code" "$duration"
    printf 'Reports: %s/%s-report.html\n' "$REPORT_DIR" "$suite_name"
done

echo
echo "Run summary:"
for index in "${!SUITES[@]}"; do
    printf '  %-28s %-4s exit=%-3s duration=%ss\n' \
        "${SUITES[$index]}" "${statuses[$index]}" "${exit_codes[$index]}" "${durations[$index]}"
done

if (( first_failure != 0 )); then
    echo "All Robot tasks were attempted; one or more suites failed." >&2
    exit "$first_failure"
fi

echo "All Robot tasks completed successfully."
