#!/bin/bash
set -euo pipefail

# Prints the line coverage of an Xcode result bundle as Markdown: the total of
# each target, then a collapsible table of files, least covered first.
# Usage: coverage-report.sh <path to .xcresult>

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <path to .xcresult>" >&2
  exit 2
fi
result_bundle_path="$1"

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
