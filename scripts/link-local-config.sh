#!/bin/bash
set -euo pipefail

# Links Configs/Local.xcconfig of the main checkout into the current worktree.
# Git ignores the file, so a new worktree lacks it and builds ad hoc, and macOS
# then asks for the Accessibility and folder permissions again on every rebuild.
# Does nothing in the main checkout, without the source file, or when the
# worktree already has the file.

readonly local_config_path="Configs/Local.xcconfig"

# The main checkout is the parent of the common Git directory, as in a plain
# `git clone`. A bare repository or `--separate-git-dir` finds no source file
# there, so the script links nothing.
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

if [[ -e "$target_path" ]]; then
  exit 0
fi

# The script still exits 0, because a failing post-checkout hook makes
# `git worktree add` exit non-zero although the worktree was created.
if [[ -L "$target_path" ]]; then
  echo "warning: ${target_path} is a dangling symbolic link; remove it and run again" >&2
  exit 0
fi

ln -s "$source_path" "$target_path"
echo "Linked ${target_path} -> ${source_path}"
