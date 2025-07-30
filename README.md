2025-07-30

# README

Download videos from youtube, cut chunks based on time intervals provided, normalise loudness, add title slides, combine into a single video. Uses yt-dlp for downloading youtube videos, uses ffmpeg for all video editing purposes.

**I am aware the docs are not good and this script is not easy to use. Work in progress.**

#### approach 1

This is black box approach I am not using anymore.

Usage
 - Download latest release of yt-dlp (older version may not work). Set env variable YTDLP with path to yt-dlp binary.
 - Configure `inputlist.txt` based on example given
 - yt_dlp works better on residential IPs not datacentre IPs, but make sure your residential ISP provides enough bandwidth + data cap to download lots of videos 
 - `./cutpaste.sh inputlist.txt`

successful test on macOS Sequoia 15.5, bash 3.2.57 (old version), on 2025-07-14

#### approach 2

This is more modular approach that gives you more control over all steps of the process.

Usage
 - Download latest release of yt-dlp (older version). Set env variable YTDLP with path to yt-dlp binary.
 - Use `download.sh` with appropriate args to download youtube videos.
 - Configure `data/input_list.txt` and `data/segments.tsv`. (Make sure locations are all correct.)
 - (Optional) Use `make_proxies.sh` with approprite args to generate lower res versions of all videos specified in input_list.txt
 - Use `segment2filter.sh` with appropriate stdin and stdout to convert input_list into a ffmpeg complex_filter_script `data/filter_coplex.txt`.
 - Use `filter2video.sh` to do the heavy-lifting. Reads `data/input_list.txt`, `data/segments.tsv` to find downloaded videos, decode them, and process them as per script `data/filter_complex.txt`. (Optional) Use `data/input_list_proxy.txt` to point to lower res versions of videos, in order to save time.

successful test on macOS Sequoia 15.5, bash 3.2.57 (old version), on 2025-07-30

#### how to search and edit clips fast

1. Use manual search or a search API to find most-upvoted youtube videos on a topic within a given date range.
2. Use yt-dlp to download subtitles for all these videos
3. Concatenate all the subtitles, take every 50k lines (assuming 1M token context window), pbcopy to clipboard, ask AI to flag timestamps that seem important for a specific query.
4. Put approx timestamps in above script, try with low-res version of video, if good try with originals.

#### how to convert horizontal 16:9 to vertical 9:16

 - jugaad - first crop to output 1:1, then add black bars to output 9:16
```
ffmpeg -i data/final_output.mp4 -vf "crop=ih:ih,pad=iw:iw*16/9:(ow-iw)/2:(oh-ih)/2:black" -c:v libx264 -crf 22 -preset fast -c:a copy data/final_output_9x16.mp4
```
 - alternatively, crop to 9:16 directly
 - adding black bars with no cropping is usually bad idea
 - crop individual clips by modifying ffmpeg complex_filter_script if you have more time

