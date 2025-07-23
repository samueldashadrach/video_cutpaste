#!/usr/bin/env bash

YTDLP="$HOME/Documents/Samuel/Software/yt-dlp_macos"

"$YTDLP" "https://youtu.be/$1" \
  --recode-video mp4 \
  --postprocessor-args "VideoConvertor+ffmpeg:-c:v libx264 -preset veryfast -crf 18 -c:a aac -b:a 192k -movflags +faststart" \
  -o "data/full_videos/%(id)s.%(ext)s"

