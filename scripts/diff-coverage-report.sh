#!/bin/bash
set -euo pipefail

# Prints, as Markdown, the line coverage of the lines that HEAD adds or changes
# since the merge base with <base ref>, followed by the uncovered changed lines.
# Only app sources under Something/ count, so that vendored code such as
# ThirdParty/ stays out of the figure.
# Usage: diff-coverage-report.sh <path to .xcresult> <base ref>

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <path to .xcresult> <base ref>" >&2
  exit 2
fi
result_bundle_path="$1"
base_ref="$2"
covered_source_directory="Something/"

repository_root=$(git rev-parse --show-toplevel)

# Prints "<path>\t<line>" for each line that HEAD adds or changes.
list_changed_lines() {
  git diff --unified=0 --no-color --no-renames --diff-filter=AM \
    "$base_ref...HEAD" -- "$covered_source_directory" |
    awk '
      /^\+\+\+ b\// { path = substr($0, 7); next }
      /^@@ / {
        # A hunk header reads "@@ -old,count +new,count @@"; a missing count
        # means one line.
        split($3, new_range, ",")
        first_line = substr(new_range[1], 2) + 0
        line_count = (2 in new_range) ? new_range[2] + 0 : 1
        for (line = first_line; line < first_line + line_count; line++) {
          print path "\t" line
        }
      }
    '
}

# Prints "<path>\t<covered>\t<executable>\t<uncovered ranges>" for one file,
# counting only its changed executable lines. Prints nothing for a file that
# the result bundle does not cover.
summarize_file() {
  local relative_path="$1"
  local changed_lines_json="$2"
  local line_coverage_json
  if ! line_coverage_json=$(xcrun xccov view --archive --json \
    --file "$repository_root/$relative_path" "$result_bundle_path" 2>/dev/null); then
    return 0
  fi
  jq -r --arg path "$relative_path" --argjson changed "$changed_lines_json" '
    def ranges:
      reduce .[] as $line ([];
        if length > 0 and .[-1][1] + 1 == $line
        then .[-1][1] = $line
        else . + [[$line, $line]] end)
      | map(if .[0] == .[1] then "\(.[0])" else "\(.[0])-\(.[1])" end)
      | join(", ");
    [.[][] | select(.isExecutable and (.line as $line | $changed | any(. == $line)))]
    | select(length > 0)
    | [$path,
       (map(select(.executionCount > 0)) | length),
       length,
       (map(select(.executionCount == 0) | .line) | ranges)]
    | @tsv
  ' <<<"$line_coverage_json"
}

summarize_changed_files() {
  local changed_lines
  changed_lines=$(list_changed_lines)
  [[ -z "$changed_lines" ]] && return 0
  local relative_path
  cut -f1 <<<"$changed_lines" | sort -u | while IFS= read -r relative_path; do
    local changed_lines_json
    changed_lines_json=$(awk -F'\t' -v path="$relative_path" \
      '$1 == path { print $2 }' <<<"$changed_lines" | jq -s -c '.')
    summarize_file "$relative_path" "$changed_lines_json"
  done
}

print_report() {
  local file_summaries="$1"
  if [[ -z "$file_summaries" ]]; then
    echo "**Changed lines**: no executable lines changed"
    return 0
  fi
  awk -F'\t' '
    { covered += $2; executable += $3 }
    END {
      permille = int(covered * 1000 / executable + 0.5)
      printf "**Changed lines**: %d.%d%% (%d / %d lines)\n", \
        int(permille / 10), permille % 10, covered, executable
    }
  ' <<<"$file_summaries"
  local uncovered_summaries
  uncovered_summaries=$(awk -F'\t' '$4 != ""' <<<"$file_summaries")
  [[ -z "$uncovered_summaries" ]] && return 0
  echo
  echo "<details>"
  echo "<summary>Uncovered changed lines</summary>"
  echo
  echo "| File | Lines |"
  echo "| --- | --- |"
  awk -F'\t' '{ printf "| %s | %s |\n", $1, $4 }' <<<"$uncovered_summaries"
  echo
  echo "</details>"
}

print_report "$(summarize_changed_files)"
