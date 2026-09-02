#!/bin/bash

# Ensures the Gogh theme catalog is cached and prints a slim JSON array on
# stdout: [{name, subtitle, variant, colors:[16 hex], background, foreground}, ...].
# Used by the GoghThemes overlay to populate the picker.

set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy/gogh-themes"
THEMES_JSON="$CACHE_DIR/themes.json"
THEMES_URL="https://raw.githubusercontent.com/Gogh-Co/Gogh/master/data/themes.json"
CACHE_MAX_AGE_MIN=1440 # 24h

mkdir -p "$CACHE_DIR"

if [[ ! -f $THEMES_JSON ]] || [[ -n $(find "$THEMES_JSON" -mmin +"$CACHE_MAX_AGE_MIN" 2>/dev/null) ]]; then
  if curl -fsSL "$THEMES_URL" -o "$THEMES_JSON.tmp"; then
    mv "$THEMES_JSON.tmp" "$THEMES_JSON"
  else
    rm -f "$THEMES_JSON.tmp"
  fi
fi

if [[ ! -f $THEMES_JSON ]]; then
  echo "[]"
  exit 0
fi

jq -c '[.[] | {
  name: .name,
  subtitle: ((if (.author // "") == "" then "Gogh" else .author end) + " - " + .variant),
  variant: .variant,
  colors: [.color_01, .color_02, .color_03, .color_04, .color_05, .color_06, .color_07, .color_08,
           .color_09, .color_10, .color_11, .color_12, .color_13, .color_14, .color_15, .color_16],
  background: .background,
  foreground: .foreground
}]' "$THEMES_JSON"
