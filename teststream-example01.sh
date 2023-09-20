#!/bin/bash

# Setze die Zielpfad-Variable
#stream_target="rtmp://192.168.100.100/live/stream"
stream_target="srt://0.0.0.0:4999?mode=listener"

# Infos zum Abruf des Streams
IPv4="$(hostname -I | awk '{print $1}')"
Port="4999"
# Der Port muss für UDP in der Firewall freigegeben werden.

# Setze die Auflösungs- und Framerate-Variablen
resolution="1920x1080"
framerate="60"

# Setze den zusätzlichen Text
extra_text="www.snowgames.live"

# Schriftart
font_file="DejaVu Sans Mono"

# FFmpeg-Befehl
ffmpeg_command="ffmpeg -loglevel error -re -f lavfi -i smptehdbars=size=$resolution:rate=$framerate \
-f lavfi -i sine=frequency=1000:sample_rate=48000:beep_factor=4 -ac 2 \
-vf \"drawtext=fontsize=50:fontfile='$font_file':fontcolor=white:x=1000:y=880:text='%{localtime\:%T}', \
    drawtext=fontsize=50:fontfile='$font_file':fontcolor=white:x=970:y=1000:text='%{pts\\:hms}', \
    drawtext=fontsize=50:fontfile='$font_file':fontcolor=white:x=20:y=20:text='$extra_text', \
    drawtext=fontsize=50:fontfile="$font_file":fontcolor=white:x=20:y=80:text='$IPv4\:$Port'\" \
-c:v libx264 -g $framerate -sc_threshold 0 -f mpegts $stream_target"

# Ausgabe des FFmpeg-Befehls
echo "Starte FFmpeg mit dem folgenden Befehl:"
echo "$ffmpeg_command"

# Ausführung des FFmpeg-Befehls
eval "$ffmpeg_command"
