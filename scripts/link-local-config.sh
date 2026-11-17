#!/bin/bash
set -euo pipefail

# Links Configs/Local.xcconfig of the main checkout into the current worktree.
# Git ignores the file, so a new worktree lacks it and builds ad hoc, and macOS
# then asks for the Accessibility and folder permissions again on every rebuild.
# Does nothing in the main checkout, without the source file, or when the
# worktree already has the file.

readonly local_config_path="Configs/Local.xcconfig"

worktree_root=$(git rev-parse --show-toplevel)
common_dir=$(git rev-parse --path-format=absolute --git-common-dir)
main_root=$(dirname "$common_dir")
readonly worktree_root common_dir main_root

if [[ "$worktree_root" == "$main_root" ]]; then
  exit 0
fi

readonly source_path="${main_root}/${local_config_path}"
readonly target_path="${worktree_root}/${local_config_path}"

if [[ ! -f "$source_path" ]]; then
  exit 0
fi

# -L catches a dangling symbolic link, which -e reports as missing.
if [[ -e "$target_path" || -L "$target_path" ]]; then
  exit 0
fi

ln -s "$source_path" "$target_path"
echo "Linked ${target_path} -> ${source_path}"
