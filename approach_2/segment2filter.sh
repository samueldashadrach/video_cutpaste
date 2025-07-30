#!/usr/bin/env bash

# written by o3, successfully tested

# HOW TO RUN
#
# ./segment2filter.sh < data/segments.tsv > data/filter_complex.txt
# 

exec 3<&0      # save current stdin (the TSV) on descriptor 3

awk -F'\t' -f - /dev/fd/3 <<'AWK'
# Escape helper ---------------------------------------------------------------
#  1. turn the two-character sequence  \n  into an actual <newline>
#  2. escape single quotes for ffmpeg
function esc(s) {
    gsub(/\\n/, "\n", s)           # \n  ->  real newline
    gsub(/'\''/, "'\\''", s)       # escape single quotes
    return s
}

BEGIN { v = 1; a = 1 }

# skip blank / comment lines
/^[[:space:]]*($|#)/ { next }

{
    type = $1

    if (type == "title") {                         # ----- slide -----
        duration = $2
        fsize    = $3
        text     = ""
        for (i = 4; i <= NF; i++) text = text FS $i   # re-join if tabs

        printf "color=c=black:s=1280x720:r=30:d=%s,\n", duration
        printf "drawtext=fontcolor=white:fontsize=%d:line_spacing=10:", fsize
        printf "x=(w-text_w)/2:y=(h-text_h)/2:text='%s',\n", esc(text)
        printf "setsar=1,format=yuv420p [v%d];\n", v
        printf "anullsrc=r=48000:cl=stereo:d=%s [a%d];\n\n", duration, a
    }
    else if (type == "file") {                      # ----- clip -----
        idx   = $2
        start = $3
        stop  = $4
        speed = (NF < 5 || $5 == "") ? 1.0 : $5

        printf "[%s:v] trim=start=%s:end=%s,"\
               "setpts=(PTS-STARTPTS)/%s,fps=30,scale=1280:-2,"\
               "setsar=1,format=yuv420p [v%d];\n", idx, start, stop, speed, v

        printf "[%s:a] atrim=start=%s:end=%s,"\
               "asetpts=PTS-STARTPTS,loudnorm=I=-16:LRA=11:TP=-1.5,atempo=%s,"\
               "aformat=sample_fmts=fltp:channel_layouts=stereo:"\
               "sample_rates=48000 [a%d];\n\n", idx, start, stop, speed, a
    }
    else {
        printf "### unknown row-type \"%s\" – line skipped ###\n", type > "/dev/stderr"
        next
    }

    chain = chain "[v" v "][a" a "]"
    ++v; ++a
}

END {
    printf "%sconcat=n=%d:v=1:a=1[vout][aout]\n", chain, v - 1
}
AWK