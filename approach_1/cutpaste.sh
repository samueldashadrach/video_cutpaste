#!/usr/bin/env bash
#
# cutpaste.sh – download YouTube videos (if needed), cut the requested
#               clips, loudness-normalise each one to –16 LUFS and
#               concatenate everything into a single MP4.
#
# written by o3
# ────────────────────────────────────────────────────────────────

set -euo pipefail
shopt -s extglob nocasematch        # [[ foo == youtube ]] / [[ foo == title ]]

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
# 2a. Loudness target (EBU R-128 / streaming-friendly)
##############################
TARGET_I=-16          # integrated loudness (LUFS)
TARGET_LRA=11         # allowed loudness range (LU)
TARGET_TP=-1.5        # true peak ceiling (dBTP)
LOUDNORM="loudnorm=I=${TARGET_I}:LRA=${TARGET_LRA}:TP=${TARGET_TP}"

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

  local s_start=${start//:/_} s_stop=${stop//:/_}
  out_file="$SNIP_DIR/${label}_${vid}_${s_start}_${s_stop}.mp4"

  ffmpeg -nostdin -hide_banner -loglevel error -y \
         -ss "$start" -to "$stop" -i "$in_file" \
         -vf "$VF" \
         -c:v libx264 -profile:v high -level 4.0 \
         -preset "$PRESET" -crf "$CRF" \
         -c:a aac -b:a 192k "$AF" \
         -af "$LOUDNORM" \
         -movflags +faststart \
         "$out_file"

  abs_out_file="$(cd "$(dirname "$out_file")" && pwd)/$(basename "$out_file")"
  printf "file '%s'\n" "$abs_out_file" >> "$CONCAT_FILE"
}

make_title_slide() {
  # $1 = duration   $2 = visible text   $3 = numeric label
  local duration="$1" raw_text="$2" label="$3"
  local out_file="$SNIP_DIR/${label}_title.mp4"

  ###############################################################
  # 1.  Honour explicit “\n”, then soft-wrap any long line
  ###############################################################
  local font_size=48               # keep in sync with drawtext below
  local avg_glyph_px=$(( font_size * 55 / 100 ))   # ≈0.55×font-size
  local max_chars=$(( WIDTH / avg_glyph_px ))

  # Turn the two-character sequence “\n” into a real newline (LF)
  local prepared_text=${raw_text//\\n/$'\n'}

  # Wrap each existing line individually; keep REAL newlines
  local wrapped
  wrapped="$(echo -e "$prepared_text" | \
             while IFS= read -r line; do
               fold -s -w "$max_chars" <<<"$line"
             done)"
  wrapped=${wrapped%$'\n'}           # drop trailing newline if any

  # Escape double quotes for drawtext
  local safe_text=${wrapped//\"/\\\"}

  ###############################################################
  # 2.  Render the title slide (silence stays silence, no loudnorm)
  ###############################################################
  ffmpeg -nostdin -hide_banner -loglevel error -y \
         -f lavfi -i "color=c=black:s=${WIDTH}x${HEIGHT}:r=${FPS}" \
         -f lavfi -i "anullsrc=r=${AUD_RATE}:cl=stereo" \
         -shortest -t "$duration" \
         -vf "${VF},drawtext=fontcolor=white:fontsize=${font_size}:line_spacing=10:text='${safe_text}':x=(w-text_w)/2:y=(h-text_h)/2" \
         -c:v libx264 -profile:v high -level 4.0 \
         -preset "$PRESET" -crf "$CRF" \
         -c:a aac -b:a 192k "$AF" \
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

  # trim leading / trailing whitespace
  line="${raw#"${raw%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"

  # split the first few tokens
  read -r keyword token2 rest <<<"$line"

  #################################
  # 5a.  Title-slide lines
  #################################
  if [[ $keyword == title ]]; then
      duration="$token2"

      # Pull everything inside DOUBLE quotes  (keeps \" if present)
      if [[ $line == *\"*\"* ]]; then
          text=${line#*\"}        # delete up to first "
          text=${text%\"*}        # delete from last " to EOL
      else
          echo "⚠︎  Malformed title line (missing double-quoted text): $line"
          continue
      fi

      idx=$((idx + 1))
      printf -v label 'clip_%03d' "$idx"
      make_title_slide "$duration" "$text" "$label"
      continue
  fi

  #################################
  # 5b.  YouTube lines
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