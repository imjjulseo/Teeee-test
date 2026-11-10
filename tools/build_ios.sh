#!/usr/bin/env bash
# Builds the iOS debug app from the "iOS" export preset (export_presets.cfg). macOS + Xcode only (Apple requirement).
# Usage (from the project root, on a Mac):
#   bash tools/build_ios.sh --check                 # only checks the setup
#   bash tools/build_ios.sh --team ABCDE12345       # writes your Apple Team ID into the preset, then builds
#   bash tools/build_ios.sh --open                  # builds, then opens the Xcode project (Run on a device / simulator from Xcode)
# Godot binary: --godot <path> > GODOT_BIN > /Applications/Godot.app/Contents/MacOS/Godot
# Setup and run steps: docs/mobile_build.md
set -euo pipefail

TEMPLATE_VERSION="4.7.2.stable"
PRESET="iOS"
OUTPUT="build/ios/swap_match.ipa"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
TEAM=""
OPEN=0
CHECK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --godot) GODOT="$2"; shift 2 ;;
    --team) TEAM="$2"; shift 2 ;;
    --open) OPEN=1; shift ;;
    --check) CHECK=1; shift ;;
    *) echo "unknown option: $1"; exit 1 ;;
  esac
done

problems=()
echo "Checking iOS export setup"
[[ "$(uname)" == "Darwin" ]] && echo "  ok   macOS" || problems+=("iOS apps can only be built on macOS with Xcode")
command -v xcodebuild >/dev/null 2>&1 && echo "  ok   Xcode: $(xcodebuild -version | head -n 1)" || problems+=("Xcode not found (install Xcode from the App Store, then run it once)")
[[ -x "$GODOT" ]] && echo "  ok   Godot: $GODOT" || problems+=("Godot binary not found: $GODOT (pass --godot or set GODOT_BIN)")
TEMPLATES="$HOME/Library/Application Support/Godot/export_templates/$TEMPLATE_VERSION/ios.zip"
[[ -f "$TEMPLATES" ]] && echo "  ok   export templates" || problems+=("iOS export templates missing: $TEMPLATES (editor: Editor > Manage Export Templates > Download and Install)")

if [[ -n "$TEAM" ]]; then
  # 프리셋의 Team ID를 바꾼다 (iOS 프리셋에만 있는 키)
  sed -i '' "s/^application\/app_store_team_id=.*/application\/app_store_team_id=\"$TEAM\"/" "$ROOT/export_presets.cfg"
  echo "  set  Team ID: $TEAM"
fi
CURRENT_TEAM="$(grep '^application/app_store_team_id=' "$ROOT/export_presets.cfg" | head -n 1 | sed 's/.*="\(.*\)"/\1/')"
[[ -n "$CURRENT_TEAM" ]] && echo "  ok   Team ID: $CURRENT_TEAM" || problems+=("Apple Team ID is empty (pass --team <ID>, or set it in the editor: Project > Export > iOS > App Store Team ID)")

if [[ ${#problems[@]} -gt 0 ]]; then
  echo
  echo "Setup is not complete:"
  for p in "${problems[@]}"; do echo "  - $p"; done
  echo "See docs/mobile_build.md"
  exit 1
fi
if [[ $CHECK -eq 1 ]]; then echo; echo "Setup OK"; exit 0; fi

mkdir -p "$ROOT/build/ios"
echo
echo "Exporting '$PRESET' (debug) -> $OUTPUT"
"$GODOT" --headless --path "$ROOT" --export-debug "$PRESET" "$OUTPUT"
PROJECT="$ROOT/build/ios/swap_match.xcodeproj"
if [[ ! -d "$PROJECT" ]]; then echo "Export failed (no Xcode project at $PROJECT)"; exit 1; fi
echo "Xcode project: $PROJECT"
[[ -f "$ROOT/$OUTPUT" ]] && echo "Signed app: $ROOT/$OUTPUT"
if [[ $OPEN -eq 1 ]]; then open "$PROJECT"; fi
exit 0