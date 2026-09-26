#!/usr/bin/env bash
# Derive WiX artwork from the single checked-in Beskid raster source.
# Usage: generate-brand-assets.sh <source-assets-dir> <output-assets-dir>
set -euo pipefail

source_dir="${1:?source assets directory}"
output_dir="${2:?output assets directory}"
source_png="${source_dir}/icons/beskid-512.png"
[[ -s "${source_png}" ]] || { echo "Missing ${source_png}" >&2; exit 1; }
command -v magick >/dev/null 2>&1 || { echo 'ImageMagick magick is required' >&2; exit 1; }

icons_dir="${output_dir}/icons"
mkdir -p "${icons_dir}"
magick "${source_png}" -strip -colorspace sRGB -background none \
  -define icon:auto-resize=256,128,96,64,48,32,16 "${icons_dir}/beskid.ico"
magick -size 493x58 xc:white \( "${source_png}" -strip -resize 46x46 \) \
  -gravity northeast -geometry +13+6 -compose over -composite \
  "${icons_dir}/beskid-msi-banner.png"
magick -size 493x312 xc:white \( "${source_png}" -strip -resize 220x220 \) \
  -gravity west -geometry +39+0 -compose over -composite \
  "${icons_dir}/beskid-msi-dialog.png"

[[ "$(magick identify -format '%wx%h' "${icons_dir}/beskid-msi-banner.png")" == '493x58' ]] || exit 1
[[ "$(magick identify -format '%wx%h' "${icons_dir}/beskid-msi-dialog.png")" == '493x312' ]] || exit 1
[[ -s "${icons_dir}/beskid.ico" ]] || exit 1
