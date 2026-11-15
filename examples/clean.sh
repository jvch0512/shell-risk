#!/usr/bin/env bash
set -euo pipefail
workdir=$(mktemp -d)
trap 'rm -rf "${workdir:?}"' EXIT
cp "$1" "$workdir/"
echo "done"
