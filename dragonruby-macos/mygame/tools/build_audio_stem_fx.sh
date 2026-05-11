#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DRB_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SRC="$DRB_ROOT/mygame/app-native/audio_stem_fx.c"
OUT="$DRB_ROOT/mygame/native/macos/audio_stem_fx.dylib"

mkdir -p "$(dirname "$OUT")"

clang -dynamiclib -O2 \
  -isystem "$DRB_ROOT/include/" \
  -isystem "$DRB_ROOT/include/mruby/" \
  -o "$OUT" \
  "$SRC"

echo "Built $OUT"
