#!/usr/bin/env bash

# written by o3, one-shot
# 
# make_proxies.sh  –  create low-quality preview files
#
#  OPTIONS
#    -il | --input_list   FILE   list of source files (default: data/input_list.txt)
#    -ol | --output_list  FILE   list to write proxy paths (default: data/input_list_proxy.txt)
#
#  Proxy parameters:
#    • original resolution
#    • 6 fps
#    • H.264  (preset ultrafast, CRF 36)
#    • AAC 64 kbit/s stereo
#    • original PTS/DTS kept (-copyts)

set -Eeuo pipefail
IFS=$'\n\t'

# ----------------------------------------------------------
# helper: absolute path
# ----------------------------------------------------------
CALL_DIR=$PWD
abspath() {
  case $1 in
    /*|~*) printf '%s\n' "$1" ;;           # already absolute / ~ expanded
    *)     printf '%s\n' "$CALL_DIR/$1" ;;
  esac
}

# ----------------------------------------------------------
# defaults
# ----------------------------------------------------------
input_list_path="data/input_list.txt"
output_list_path="data/input_list_proxy.txt"
fps_fixed=6

# ----------------------------------------------------------
# parse options
# ----------------------------------------------------------
while (($#)); do
  case $1 in
    -il|--input_list)  input_list_path="$2"; shift 2 ;;
    -ol|--output_list) output_list_path="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

input_list_path=$(abspath "$input_list_path")
output_list_path=$(abspath "$output_list_path")

[[ -r $input_list_path ]] \
  || { echo "Input list '$input_list_path' not found/readable" >&2; exit 1; }

echo "Generating proxies (lowered fps, same resolution)…"
proxy_paths=()

# ----------------------------------------------------------
# main loop
# ----------------------------------------------------------
while IFS= read -r line || [[ -n $line ]]; do
  # skip blank lines and comment lines
  [[ -z $line || "${line#\#}" != "$line" ]] && continue

  src=$(abspath "$line")
  [[ -r $src ]] || { echo " !  Source '$src' not found – skipped" >&2; continue; }

  dir=$(dirname  "$src")
  base=$(basename "$src")
  proxy="${dir}/.proxy_${base%.*}.mp4"
  proxy_paths+=("$proxy")

  if [[ -f $proxy ]]; then
      echo " ✓  $proxy  (exists – skipped)"
      continue
  fi

  echo " →  $proxy"

  ffmpeg -nostdin -y -loglevel error \
         -copyts -i "$src" \
         -vf "fps=${fps_fixed}" \
         -c:v libx264 -preset ultrafast -crf 36 \
         -c:a aac -b:a 64k \
         "$proxy"
done < "$input_list_path"

# ----------------------------------------------------------
# write list of proxies
# ----------------------------------------------------------
printf '%s\n' "${proxy_paths[@]}" > "$output_list_path"
echo "Proxy list written to $output_list_path"
echo "Done."