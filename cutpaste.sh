#!/usr/bin/env bash

# Written by o3, may contain hallucins, tested, working

# cutpaste.sh – download YouTube videos (if needed), cut the requested
#               clips, and concatenate them into a single MP4.
#
# Extended 2025-07-13: you can now add title slides:
#         title  <HH:MM:SS | MM:SS | SS>  'some text here'
#
# Example:  title 00:05 'where we are now'
#
# ────────────────────────────────────────────────────────────────────

set -euo pipefail
shopt -s extglob nocasematch     # [[ foo == youtube ]] / [[ foo == title ]] → case-insensitive

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
HEIGHT=720            # reference height used for synthetic title slides
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
  [[ -e "$OUT_DIR/$vid.mp4" ]] && return
  "$YTDLP" -o "$OUT_DIR/%(id)s.%(ext)s" --merge-output-format mp4 "$url"
}

cut_clip() {
  local url="$1" start="$2" stop="$3" label="$4"

  download_if_necessary "$url"

  local vid in_file out_file abs_out_file
  vid="$(get_vid_id "$url")"
  in_file="$OUT_DIR/$vid.mp4"

  local s_start=${start//:/-} s_stop=${stop//:/-}
  out_file="$SNIP_DIR/${label}_${s_start}_${s_stop}.mp4"

  ffmpeg -nostdin -hide_banner -loglevel error -y \
         -ss "$start" -to "$stop" -i "$in_file" \
         -vf "$VF" \
         -c:v libx264 -profile:v high -level 4.0 \
         -preset "$PRESET" -crf "$CRF" \
         -c:a aac -b:a 192k $AF \
         -movflags +faststart \
         "$out_file"

  abs_out_file="$(cd "$(dirname "$out_file")" && pwd)/$(basename "$out_file")"
  printf "file '%s'\n" "$abs_out_file" >> "$CONCAT_FILE"
}

make_title_slide() {
  # $1 = duration   $2 = visible text   $3 = numeric label
  local duration="$1" text="$2" label="$3"
  local out_file="$SNIP_DIR/${label}_title.mp4"

  # escape single quotes for drawtext
  local safe_text=${text//\'/\\\'}

  ffmpeg -nostdin -hide_banner -loglevel error -y \
         -f lavfi -i "color=c=black:s=${WIDTH}x${HEIGHT}" \
         -f lavfi -i "anullsrc=r=${AUD_RATE}:cl=stereo" \
         -shortest -t "$duration" \
         -vf "drawtext=fontcolor=white:fontsize=64:text='${safe_text}':x=(w-text_w)/2:y=(h-text_h)/2,format=yuv420p" \
         -c:v libx264 -profile:v high -level 4.0 \
         -preset "$PRESET" -crf "$CRF" \
         -c:a aac -b:a 192k $AF \
         -movflags +faststart \
         "$out_file"

  local abs_out_file
  abs_out_file="$(cd "$(dirname "$out_file")" && pwd)/$(basename "$out_file")"
  printf "file '%s'\n" "$abs_out_file" >> "$CONCAT_FILE"
}

##############################
# 5.  Main loop – read list file
##############################
idx=0
while IFS= read -r raw || [[ -n $raw ]]; do
  [[ $raw =~ ^[[:space:]]*$ ]] && continue   # blank
  [[ $raw =~ ^[[:space:]]*# ]] && continue   # comment

  # trim
  line="${raw#"${raw%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"

  # split the first few tokens
  read -r keyword token2 rest <<<"$line"

  #################################
  # 5a.  Title-slide lines
  #################################
  if [[ $keyword == title ]]; then
      duration="$token2"

      # pull everything inside single quotes
      if [[ $line =~ \'(.*)\' ]]; then
          text="${BASH_REMATCH[1]}"
      else
          echo "⚠︎  Malformed title line (missing single-quoted text): $line"
          continue
      fi

      idx=$((idx + 1))
      printf -v label 'clip_%03d' "$idx"
      make_title_slide "$duration" "$text" "$label"
      continue
  fi

  #################################
  # 5b.  YouTube lines (unchanged)
  #################################
  [[ $keyword != youtube ]] && continue

  # token2 is either a bare 11-char ID or a full URL
  id_or_url="$token2"
  read -r start stop extra <<<"$rest"
  [[ -n ${extra-} ]] && continue   # ignore malformed lines

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