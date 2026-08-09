#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is required. This checkout is pinned to Flutter 3.35.7 in .fvmrc." >&2
  exit 1
fi

if ! command -v bun >/dev/null 2>&1; then
  echo "Bun is required to generate the bundled JS runtime and source templates." >&2
  echo "Install it with: brew install oven-sh/bun/bun" >&2
  exit 1
fi

bash script/fetch_git_info.sh
flutter pub get --enforce-lockfile
flutter pub run build_runner build --delete-conflicting-outputs

mkdir -p packages/xi/assets/js
rm -f JS/bundle/bun.lock JS/cli/bun.lock \
  packages/xi/lib/adapters/templates/bun.lock

pushd JS/bundle >/dev/null
bun install --no-save
bun run build
popd >/dev/null
cp JS/bundle/dist/kitty.umd.js packages/xi/assets/js/kitty.umd.js

pushd JS/cli >/dev/null
bun install --no-save
popd >/dev/null

pushd packages/xi/lib/adapters/templates >/dev/null
bun install --no-save
bun run build
popd >/dev/null

echo "Build prerequisites are ready."
