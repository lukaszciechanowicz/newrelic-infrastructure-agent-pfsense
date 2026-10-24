#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
set -eu

if [ "$#" -gt 1 ]; then
    printf 'Usage: sh scripts/prepare-source.sh [output-directory]\n' >&2
    exit 1
fi
case "$0" in
    */*) script_dir=${0%/*} ;;
    *) script_dir=. ;;
esac
case "$script_dir" in
    /*) ;;
    *) script_dir="$PWD/$script_dir" ;;
esac
project=$(CDPATH= cd "$script_dir/.." && pwd)
. "$project/upstream.env"
: "${UPSTREAM_REPOSITORY:?Missing upstream repository}"
: "${UPSTREAM_COMMIT:?Missing upstream commit}"
: "${SOURCE_PATCH:?Missing source patch}"

output=${1:-"$project/work/source"}
case "$output" in
    /*) ;;
    *) output="$PWD/$output" ;;
esac
while [ "${output%/}" != "$output" ] && [ "$output" != / ]; do
    output=${output%/}
done
if [ -e "$output" ] || [ -L "$output" ]; then
    printf 'Refusing existing destination: %s\n' "$output" >&2
    exit 1
fi
if [ ! -f "$project/$SOURCE_PATCH" ]; then
    printf 'Missing source patch: %s\n' "$project/$SOURCE_PATCH" >&2
    exit 1
fi
mkdir -p "${output%/*}"
# Atomic creation also refuses a destination created after the check above.
mkdir "$output"
git init -q "$output"
git -C "$output" remote add origin "$UPSTREAM_REPOSITORY"
git -C "$output" fetch --depth=1 origin "$UPSTREAM_COMMIT"
git -C "$output" checkout -q --detach FETCH_HEAD
if [ "$(git -C "$output" rev-parse HEAD)" != "$UPSTREAM_COMMIT" ]; then
    printf 'Fetched commit does not match upstream.env\n' >&2
    exit 1
fi
git -C "$output" apply --index "$project/$SOURCE_PATCH"
printf 'Prepared patched source: %s\n' "$output"
printf 'Base commit: %s; applied patch: %s\n' "$UPSTREAM_COMMIT" "$SOURCE_PATCH"
