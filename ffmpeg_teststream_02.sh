#!/usr/bin/env bash
set -Eeuo pipefail

# ---------------------------------------
# SnowgamesLive Teststream → SRT
# 1080p50, 6 Mbit/s, Datum + Uhrzeit + Ticker
# Audio: 440 Hz mit L/R-Pendeln + 1 kHz Beeps alternierend L/R
# FFmpeg ≥ 6.x (Ubuntu 24.04 ok)
#
# Achtung, kostet jede Menge CPU-Leistung !!
# läuft deshalb nicht auf einem RaspberryPi 4
# ---------------------------------------

# ---- Konfiguration (bei Bedarf hier anpassen) ----
HOST="192.168.95.18"
PORT="8890"
STREAMID="snowgames-test"

SIZE="1920x1080"
FPS="50"
FONT="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

# Video-Encoding
V_PRESET="fast"
V_TUNE="animation"
V_PROFILE="high"
V_LEVEL="4.2"
V_BITRATE="6000k"
V_MAXRATE="6000k"
V_BUFSIZE="12000k"
GOP="100"
BF="3"
RC_LOOKAHEAD="25"
REFS="4"
SC_THRESHOLD="40"

# Audio-Encoding
A_BITRATE="128k"
A_SR="48000"

# SRT
LATENCY_MS="200"
PKT_SIZE="1316"
# Hinweis: Falls dein Server 'publish:' nicht erwartet, einfach weglassen:
SRT_URL="srt://${HOST}:${PORT}?mode=caller&latency=${LATENCY_MS}&pkt_size=${PKT_SIZE}&streamid=publish:${STREAMID}"

# ---- Checks (minimal & unaufdringlich) ----
command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg nicht gefunden"; exit 127; }
[[ -f "$FONT" ]] || echo "Warnung: Font nicht gefunden: $FONT"

# ---- Start ----
exec ffmpeg -re \
-f lavfi -i "testsrc2=size=${SIZE}:rate=${FPS},\
drawbox=x=0:y=ih-80:w=iw:h=80:color=black@0.6:t=fill,\
drawtext=fontfile=${FONT}:text='%{localtime\:%d.%m.%y}':x=3:y=80:fontsize=80:fontcolor=white:box=1:boxcolor=0x00000088,\
drawtext=fontfile=${FONT}:text='%{localtime\\:%H\\\\\\:%M\\\\\\:%S}':x=400:y=80:fontsize=80:fontcolor=white:box=1:boxcolor=0x00000088,\
drawtext=fontfile=${FONT}:text='   www.Snowgames.Live   ':x=w-mod(t*200\,w+tw):y=h-60:fontsize=48:fontcolor=red:shadowx=2:shadowy=2" \
-f lavfi -i "sine=frequency=440:sample_rate=${A_SR}" \
-f lavfi -i "aevalsrc=exprs='between(mod(t,2),0,0.06)*sin(2*PI*1000*t)':s=${A_SR}" \
-f lavfi -i "aevalsrc=exprs='between(mod(t+1,2),0,0.06)*sin(2*PI*1000*t)':s=${A_SR}" \
-filter_complex "[1:a]aformat=channel_layouts=stereo,apulsator=mode=sine:hz=0.2:width=1.0[base];[2:a]aformat=channel_layouts=stereo,pan=stereo|c0=c0|c1=0*c0[beepL];[3:a]aformat=channel_layouts=stereo,pan=stereo|c0=0*c0|c1=c0[beepR];[base][beepL][beepR]amix=inputs=3:normalize=0[aout]" \
-map 0:v -map "[aout]" -pix_fmt yuv420p \
-c:v libx264 -preset "$V_PRESET" -tune "$V_TUNE" -profile:v "$V_PROFILE" -level "$V_LEVEL" \
-b:v "$V_BITRATE" -maxrate "$V_MAXRATE" -bufsize "$V_BUFSIZE" -g "$GOP" \
-bf "$BF" -b_strategy 2 -rc-lookahead "$RC_LOOKAHEAD" -refs "$REFS" -sc_threshold "$SC_THRESHOLD" \
-color_primaries bt709 -color_trc bt709 -colorspace bt709 \
-c:a aac -b:a "$A_BITRATE" -ar "$A_SR" -ac 2 \
-f mpegts "$SRT_URL"

# ---- Doku ----
# Video:
#  - Testbild 1920x1080@50
#  - Transparenter Balken unten
#  - Datum (%d.%m.%y) links, Uhrzeit (HH:MM:SS) daneben – exakt wie bei dir funktionierend
#  - Roter Ticker "www.Snowgames.Live" (Laufschrift)
# Audio:
#  - 440 Hz Grundton mit L/R-Pendeln
#  - 1 kHz Beep, 60 ms, abwechselnd L/R im Sekundentakt
# Encoding:
#  - H.264 High@4.2, 6 Mbit/s, GOP=100 (2 s @50 fps), BT.709
#  - AAC 128k Stereo @48 kHz
# Ausgabe:
#  - SRT Caller → $HOST:$PORT, StreamID 'publish:$STREAMID', Latenz ${LATENCY_MS} ms, pkt_size ${PKT_SIZE}
