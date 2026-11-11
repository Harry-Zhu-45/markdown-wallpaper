#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
input="${1:-todo.md}"
output="${2:-output/todo.png}"
width="${3:-1080}"
height="${4:-1920}"

if [[ "$input" != /* ]]; then
  input="$project_root/$input"
fi

if [[ "$output" != /* ]]; then
  output="$project_root/$output"
fi

if [[ ! -f "$input" ]]; then
  printf 'Markdown file not found: %s\n' "$input" >&2
  exit 1
fi

if [[ ! "$width" =~ ^[0-9]+$ || ! "$height" =~ ^[0-9]+$ ]]; then
  printf 'Width and height must be positive integers.\n' >&2
  exit 1
fi

if (( width < 320 || width > 7680 || height < 320 || height > 7680 )); then
  printf 'Width and height must be between 320 and 7680.\n' >&2
  exit 1
fi

if [[ "${output,,}" != *.png ]]; then
  printf 'Output file must end in .png: %s\n' "$output" >&2
  exit 1
fi

mkdir -p -- "$(dirname -- "$output")"
temp_dir="$(mktemp -d)"
trap 'rm -rf -- "$temp_dir"' EXIT

pandoc "$input" \
  --from=markdown \
  --standalone \
  --top-level-division=section \
  --pdf-engine=xelatex \
  --include-in-header="$project_root/theme.tex" \
  --variable="geometry:paperwidth=135mm,paperheight=240mm,top=10mm,bottom=12mm,left=10mm,right=10mm" \
  --variable="fontsize=9pt" \
  --variable="mainfont=Noto Sans" \
  --variable="CJKmainfont=Noto Sans CJK SC" \
  --variable="monofont=DejaVu Sans Mono" \
  --variable="linestretch=1.08" \
  --variable="colorlinks=true" \
  --output="$temp_dir/render.pdf"

pages="$(pdfinfo "$temp_dir/render.pdf" | awk '/^Pages:/ { print $2 }')"
if [[ "$pages" != "1" ]]; then
  printf 'Markdown rendered to %s pages; a fixed wallpaper PNG must fit on one page.\n' "$pages" >&2
  printf 'Shorten the document or reduce the font size in render.sh.\n' >&2
  exit 1
fi

pdftocairo \
  -png \
  -singlefile \
  -scale-to-x "$width" \
  -scale-to-y "$height" \
  "$temp_dir/render.pdf" \
  "$temp_dir/render"

mv -- "$temp_dir/render.png" "$output"
printf 'PNG generated: %s (%sx%s)\n' "$output" "$width" "$height"
