2025-07-14

# README

Download videos from youtube, cut chunks based on time intervals provided, normalise loudness, add title slides, combine into a single video

Usage: `./cutpaste.sh inputlist.txt`

See `inputlist.txt` for an example.

Uses yt-dlp for downloading youtube videos, uses ffmpeg for all video editing purposes.

yt_dlp works better on residential IPs not datacentre IPs, but make sure your residential ISP provides enough bandwidth + data cap to download lots of videos 

successful test on macOS Sequoia 15.5, bash 3.2.57 (old version), on 2025-07-14