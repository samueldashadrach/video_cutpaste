#!/usr/bin/env bash

# written by o3, successfully tested

# TO DO: (maybe unsolveable) figure out how to reduce time taken by script.
# currently this script decodes entire 2 hours videos.
# decoding only certain chunks means abandoning the filter script based approach.

# HOW TO RUN
# 
# ./filter2video.sh -il data/input_list.txt -vpre data/libx264.ffpreset -apre data/aac.ffpreset -o data/final_output.mp4 -fc data/filter_complex.txt
# 

CALL_DIR=$PWD           # directory where *command* was executed
abspath() {
  case $1 in
    /*|~*) printf '%s\n' "$1" ;;           # already absolute (or ~ expanded)
    *)     printf '%s\n' "$CALL_DIR/$1" ;; # make it absolute
  esac
}

# Defaults
inputs=()
input_list_path=$(abspath "data/input_list.txt")
output=$(abspath "data/final_output.mp4")
vpre_path=$(abspath "data/libx264.ffpreset")
apre_path=$(abspath "data/aac.ffpreset")
filter_complex_path=$(abspath "data/filter_complex.txt")

while (($#)); do
  case $1 in
    -il|--input_list)     input_list_path="$(abspath "$2")"; shift 2 ;;
    # -i|--input)            inputs+=("$(abspath "$2")");             shift 2 ;;
    -o|--output)           output="$(abspath "$2")";                shift 2 ;;
    -vpre|--vpre)          vpre_path="$(abspath "$2")";             shift 2 ;;
    -apre|--apre)          apre_path="$(abspath "$2")";             shift 2 ;;
    -fc|--filter_complex)  filter_complex_path="$(abspath "$2")";   shift 2 ;;
    *)                                                         shift ;;
  esac
done

while IFS= read -r line || [[ -n "$line" ]]
do
  [[ -z "$line" || "${line#\#}" != "$line" ]] && continue # skip empty lines
  inputs+=("$(abspath "$line")")
done < "$input_list_path"

mkdir -p "$HOME/.ffmpeg"
vpre_name="${vpre_path##*/}";  vpre_name="${vpre_name%.ffpreset}"
apre_name="${apre_path##*/}";  apre_name="${apre_name%.ffpreset}"

ln -sf "$vpre_path" "$HOME/.ffmpeg/${vpre_name}.ffpreset"
ln -sf "$apre_path" "$HOME/.ffmpeg/${apre_name}.ffpreset"

cmd=(
  ffmpeg -y -loglevel error -hwaccel videotoolbox
)
for f in "${inputs[@]}"
do cmd+=(
  -i "$f"
)
done
cmd+=(
  -map "[vout]" -map "[aout]"
  -c:v libx264 -vpre "$vpre_name"
  -c:a aac      -apre "$apre_name"
  -filter_complex "$(cat "$filter_complex_path")"
  -movflags +faststart "$output"
)

echo "started at: $(date)"
# echo "${cmd[@]}" # for debugging only
"${cmd[@]}"
echo "completed at: $(date)"
