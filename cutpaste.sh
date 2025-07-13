#!/usr/bin/env bash

# Written by o3, may contain hallucins, tested, working

# cutpaste.sh – download YouTube videos (if needed), cut the requested
#               clips, and concatenate them into a single MP4.
#
# Usage:  ./cutpaste.sh [path/to/inputlist.txt]
#         If no argument is given, it defaults to data/inputlist.txt
#
# Each non-blank, non-comment line of the list file must contain:
#       <video-id | full-URL>  <start-time>  <stop-time>
#
# Example line:
#       dQw4w9WgXcQ  00:15  00:42
#
# ────────────────────────────────────────────────────────────────────

set -euo pipefail
shopt -s extglob

##############################
# 1.  Path configuration
##############################
DATA_DIR="data"                             # base directory for everything

LIST_FILE="${1:-$DATA_DIR/inputlist.txt}"   # may be overridden by user
OUT_DIR="$DATA_DIR/full_videos"
SNIP_DIR="$DATA_DIR/snippets"
CONCAT_FILE="$DATA_DIR/concat_list.txt"
FINAL="$DATA_DIR/final_output.mp4"

##############################
# 2.  Encoding / download settings
##############################
YTDLP="$HOME/Documents/Samuel/Software/yt-dlp_macos"   # adjust if needed

CRF=23
PRESET="veryfast"
FPS=30
WIDTH=1280
AUD_RATE=48000

VF="fps=${FPS},scale=${WIDTH}:-2,setsar=1,format=yuv420p"
AF="-ar ${AUD_RATE}"

##############################
# 3.  Prepare filesystem
##############################
rm -rf "$SNIP_DIR"
mkdir -p "$OUT_DIR" "$SNIP_DIR"
: > "$CONCAT_FILE"            # truncate concat list

##############################
# 4.  Helper functions
##############################
get_vid_id() {
  # Extract the 11-char YouTube video ID from (almost) any URL
  local url="$1" id=""
  case "$url" in
    *youtu.be/*)  id="${url##*youtu.be/}"; id="${id%%\?*}" ;;
    *watch?v=*)   id="${url##*v=}";        id="${id%%\&*}" ;;
    *)            id="$("$YTDLP" --print id --skip-download "$url")" ;;
  esac
  printf '%s' "$id"
}

download_if_necessary() {
  local url="$1" vid
  vid="$(get_vid_id "$url")"
  [[ -e "$OUT_DIR/$vid.mp4" ]] && return        # already downloaded
  "$YTDLP" -o "$OUT_DIR/%(id)s.%(ext)s" --merge-output-format mp4 "$url"
}

cut_clip() {
  local url="$1" start="$2" stop="$3" label="$4"

  download_if_necessary "$url"

  local vid in_file out_file abs_out_file
  vid="$(get_vid_id "$url")"
  in_file="$OUT_DIR/$vid.mp4"

  # make a nice file name for the snippet
  local s_start=${start//:/-} s_stop=${stop//:/-}
  out_file="$SNIP_DIR/${label}_${s_start}_${s_stop}.mp4"

  # cut / re-encode the requested segment
  ffmpeg -nostdin -hide_banner -loglevel error -y \
         -ss "$start" -to "$stop" -i "$in_file" \
         -vf "$VF" \
         -c:v libx264 -profile:v high -level 4.0 \
         -preset "$PRESET" -crf "$CRF" \
         -c:a aac -b:a 192k $AF \
         -movflags +faststart \
         "$out_file"

  # ------------------------------------------------------------------
  # IMPORTANT FIX: write an ABSOLUTE path to the concat list,
  # so FFmpeg never prepends another "data/" layer
  # ------------------------------------------------------------------
  abs_out_file="$(cd "$(dirname "$out_file")" && pwd)/$(basename "$out_file")"
  printf "file '%s'\n" "$abs_out_file" >> "$CONCAT_FILE"
}

##############################
# 5.  Main loop – read list file
##############################
idx=0
while IFS= read -r raw || [[ -n $raw ]]; do
  [[ $raw =~ ^[[:space:]]*$ ]] && continue      # skip blank lines
  [[ $raw =~ ^[[:space:]]*# ]] && continue      # skip comments

  # trim leading/trailing whitespace
  line="${raw#"${raw%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"

  # split the line into up to 3 fields
  read -r id_or_url start stop extra <<<"$line"
  [[ -n ${extra-} ]] && continue                # ignore malformed lines

  # turn bare video-ID into full URL
  if [[ $id_or_url =~ ^[A-Za-z0-9_-]{11}$ ]]; then
    url="https://www.youtube.com/watch?v=$id_or_url"
  else
    url="$id_or_url"
  fi

  idx=$((idx + 1))
  printf -v label 'clip_%03d' "$idx"
  cut_clip "$url" "$start" "$stop" "$label"
done < "$LIST_FILE"

##############################
# 6.  Concatenate all snippets
##############################
ffmpeg -nostdin -hide_banner -loglevel error -y \
       -f concat -safe 0 -i "$CONCAT_FILE" \
       -c copy -movflags +faststart "$FINAL"

echo "✓ Finished – final video written to: $FINAL"