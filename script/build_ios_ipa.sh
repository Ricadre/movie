#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is required. Install Flutter 3.44.9 first." >&2
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "A full Xcode installation is required (Command Line Tools alone are insufficient)." >&2
  exit 1
fi

bash script/prepare_build.sh
flutter build ios --release --no-codesign --no-pub --verbose

app_path="$(find build/ios/iphoneos -maxdepth 1 -type d -name '*.app' -print -quit)"
if [[ -z "$app_path" ]]; then
  echo "The iOS .app bundle was not produced." >&2
  exit 1
fi

temporary_dir="$(mktemp -d "${TMPDIR:-/tmp}/catmovie-ipa.XXXXXX")"
trap 'rm -rf "$temporary_dir"' EXIT

mkdir -p "$temporary_dir/Payload" build/ios/ipa
ditto "$app_path" "$temporary_dir/Payload/CatMovie.app"

ipa_path="$project_root/build/ios/ipa/catmovie-2.5.9-dynamic-live-unsigned.ipa"
rm -f "$ipa_path"
ditto -c -k --sequesterRsrc --keepParent "$temporary_dir/Payload" "$ipa_path"

echo "Created: $ipa_path"
echo "Re-sign this IPA with AltStore, SideStore, Sideloadly, or your Apple certificate."
