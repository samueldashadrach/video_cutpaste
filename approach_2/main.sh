#!/usr/bin/env bash

# TO DO: (maybe unsolveable) figure out how to reduce time taken by script.
# currently this script decodes entire 2 hours videos.
# decoding only certain chunks means abandoning the filter script based approach.

mkdir -p ~/.ffmpeg
rm -rf ~/.ffmpeg/libx264.ffpreset ~/.ffmpeg/aac.ffpreset
ln -s "$PWD/data/libx264.ffpreset"  ~/.ffmpeg/libx264.ffpreset
ln -s "$PWD/data/aac.ffpreset"      ~/.ffmpeg/aac.ffpreset

echo "started at: " && date

ffmpeg \
  -i                      data/full_videos/q27XMPm5wg8.mp4 \
  -i                      data/full_videos/3FIo6evmweo.mp4 \
  -filter_complex         "$(cat "$1")" \
  -map "[vout]" -map "[aout]" \
  -c:v libx264 -vpre libx264 \
  -c:a aac -apre aac \
  -movflags +faststart    data/final_output.mp4 \
  -hwaccel videotoolbox \
  -y -loglevel error # to increase loglevel: error, info, verbose, debug or trace

echo "completed at: " && date
