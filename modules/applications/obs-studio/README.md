# Native demo recording

OBS and FFmpeg are selected by both desktop profiles. Linux also includes
wl-screenrec. macOS already supplies `/usr/sbin/screencapture`.

## OBS setup

Create a `Native demo` profile and scene collection after activation:

1. Set both canvas and output to 1920×1080, with 30 fps.
2. On Niri, add **Window Capture (PipeWire)** and select the app in the portal.
   On macOS, add **macOS Screen Capture**, select Window Capture, and grant OBS
   Screen & System Audio Recording permission in System Settings.
3. Keep the app at its normal desktop-managed size. Use Transform → Fit to Screen
   to preserve aspect ratio and pad unused space. Crop only irrelevant content;
   never stretch text or resize the desktop to fit the video.
4. Record H.264 to MKV, then use File → Remux Recordings to produce MP4.
   Start with x264 CRF 18, veryfast, or AMD VA-API CQP 18 on Othinus.
   On Proserpina, use Apple VT H.264 Hardware with the High Quality preset.
   Hardware settings still need a short recording check in OBS on each machine.
5. Disable microphone/desktop audio unless the demo needs them.

## Agent capture

On Niri, capture a region in logical desktop coordinates; stop with Ctrl+C or
SIGINT. Keep the app visible and stationary because this captures the region,
including anything covering it. The AMD device below is specific to Othinus.

```sh
wl-screenrec --no-damage --max-fps 30 --codec avc --low-power off \
  --dri-device /dev/dri/by-path/pci-0000:07:00.0-render \
  --bitrate '5 MB' --geometry 'X,Y WIDTHxHEIGHT' --filename capture.mkv
```

On macOS, list AVFoundation devices, then use the index for **Capture screen 0**
(1 on Proserpina during validation). This records a continuous display source;
crop to the app's physical pixel bounds during export.

```sh
ffmpeg -f avfoundation -list_devices true -i ''
ffmpeg -f avfoundation -framerate 30 -pixel_format nv12 -capture_cursor 1 \
  -i '1:none' -t 15 -r 30 -c:v h264_videotoolbox -b:v 30M capture.mkv
```

Device listing exits with an input error after printing the list. Grant the
recording process Screen Recording permission if macOS requests it. Both CLI
recorders require an unlocked graphical session. macOS also provides
`screencapture -v -V 15 -R X,Y,WIDTH,HEIGHT capture.mov`, with adaptive frame timing.

Export a continuous capture with aspect-preserving scaling and padding:

```sh
ffmpeg -i capture.mkv \
  -vf 'scale=1920:1080:force_original_aspect_ratio=decrease:force_divisible_by=2:flags=lanczos,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,setsar=1' \
  -r 30 -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -movflags +faststart demo.mp4
```

For a display capture, prepend `crop=W:H:X:Y,` to the export filter to isolate
the app. Never use screenshot loops as video input.
Show the starting state, deliberate interaction, and visible result with pauses
long enough to read. Play the actual exported MP4 before sharing; inspect text,
motion, framing, and audio. Check encoding with:

```sh
ffprobe -v error -count_frames -select_streams v:0 \
  -show_entries stream=codec_name,width,height,avg_frame_rate,nb_read_frames demo.mp4
ffmpeg -v error -i demo.mp4 -f null -
```
