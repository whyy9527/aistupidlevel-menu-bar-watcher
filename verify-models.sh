#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

swiftc \
  "$script_dir/Sources/AIStupidLevelWatcher/Models.swift" \
  "$script_dir/Tests/ModelChecks.swift" \
  -o "$temp_dir/model-checks"

"$temp_dir/model-checks"
