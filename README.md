2025-07-14

# README

Download videos from youtube, cut chunks based on time intervals provided, normalise loudness, add title slides, combine into a single video. Uses yt-dlp for downloading youtube videos, uses ffmpeg for all video editing purposes.

Usage
 - Download latest release of yt-dlp (older version may not work). Set env variable YTDLP with path to yt-dlp binary.
 - Configure `inputlist.txt` based on example given
 - yt_dlp works better on residential IPs not datacentre IPs, but make sure your residential ISP provides enough bandwidth + data cap to download lots of videos 
 - `./cutpaste.sh inputlist.txt`

successful test on macOS Sequoia 15.5, bash 3.2.57 (old version), on 2025-07-14