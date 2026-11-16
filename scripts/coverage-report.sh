#!/bin/bash
set -euo pipefail

# Prints the line coverage of an Xcode result bundle as Markdown: the total of
# each target, then the coverage of the lines changed since [base ref] when the
# argument is given, then a collapsible table of files, least covered first.
# Usage: coverage-report.sh <path to .xcresult> [base ref]

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <path to .xcresult> [base ref]" >&2
  exit 2
fi
result_bundle_path="$1"
base_ref="${2:-}"
script_directory=$(cd "$(dirname "$0")" && pwd)

coverage_json=$(xcrun xccov view --report --json "$result_bundle_path")
# Keeps one decimal place, such as "9.0%", so that the right-aligned column of
# percentages lines up.
jq_percent_definition='def percent: . * 1000 | round | "\(. / 10 | floor).\(. % 10)%";'

echo "## Unit Test Coverage"
echo
jq -r "$jq_percent_definition"'
  .targets[]
  | "**\(.name)**: \(.lineCoverage | percent) (\(.coveredLines) / \(.executableLines) lines)"
' <<<"$coverage_json"
if [[ -n "$base_ref" ]]; then
  echo
  "$script_directory/diff-coverage-report.sh" "$result_bundle_path" "$base_ref"
fi
echo
echo "<details>"
echo "<summary>Coverage by file</summary>"
echo
echo "| File | Coverage | Covered lines |"
echo "| --- | ---: | ---: |"
jq -r "$jq_percent_definition"'
  [.targets[].files[]]
  | sort_by(.lineCoverage, .name)[]
  | "| \(.name) | \(.lineCoverage | percent) | \(.coveredLines) / \(.executableLines) |"
' <<<"$coverage_json"
echo
echo "</details>"
