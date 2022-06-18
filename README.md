# testStreamGenerator

getestet auf Ubuntu 20.04  
>Ich habe diesen "TestStreamGenerator" auf einem kleinen virtuellen Server in der Cloud laufen. Ich simuliere damit Streams, um z.B. zu testen, ob OBS oder vMix Instanzen, die ich in der Cloud installiert habe, Streams empfangen können.  
**... und paar Ideen.**

# Installationen
## srt-live-ransmit
>The srt-live-transmit tool is a universal data transport tool with a purpose to transport data between SRT and other medium. At the same time it is just a sample application to show some of the powerful features of SRT. We encourage you to use SRT library itself integrated into your products.  

```
sudo apt install tclsh pkg-config cmake libssl-dev build-essential -y
cd /usr/bin
git clone https://github.com/Haivision/srt.git
cd srt
./configure
make
sudo make install

```
Das Folgende kannst du in ein Skript einfügen, um zu prüfen, ob die Installation erfolgreich war.
```
# test if srt-live-transmit was installed correctly
srt_version="$(srt-live-transmit -version 2>&1)"
if (echo $srt_version | grep -q 'SRT Library version'); then
    echo $srt_version "was successfully installed" >>$inst_logfile
else
    echo "error: srt-live-transmit was not installed correctly" >>$inst_logfile
    echo "The installation was terminated due to an error during the installation of SRT."
    exit
fi

```   
> Da ich im Folgenden einen "Static Build" von FFmpeg installiere, bei dem die SRT Bibliothek schon eingebunden ist, muss srt-live-transmit eigentlich nicht, wie oben beschrieben, installiert werden. Für weitere spätere Testzwecke habe ich srt-live-transmit trotzdem schon mal installiert.  

## FFmpeg
> FFmpeg is the leading multimedia framework, able to decode, encode, transcode, mux, demux, stream, filter and play pretty much anything that humans and machines have created. It supports the most obscure ancient formats up to the cutting edge. No matter if they were designed by some standards committee, the community or a corporation. It is also highly portable: FFmpeg compiles, runs, and passes our testing infrastructure FATE across Linux, Mac OS X, Microsoft Windows, the BSDs, Solaris, etc. under a wide variety of build environments, machine architectures, and configurations.

```
cd /usr/bin
wget https://johnvansickle.com/ffmpeg/builds/ffmpeg-git-amd64-static.tar.xz
tar xvf ffmpeg-git-amd64-static.tar.xz
current_ffmpeg=$(ls | grep ffmpeg-git-20)
cd $current_ffmpeg
sudo mv ffmpeg ffprobe /usr/local/bin/
```
Das Folgende kannst du in einem Script verwenden, um zu prüfen , ob die Installation erfolgreich war.

```
# test if FFmpeg was installed correctly
ffmpeg_version="$(ffmpeg -version | grep version -m 1 2>&1)"
if (echo $ffmpeg_version | grep -q 'ffmpeg version'); then
    echo $ffmpeg_version "was successfully installed" >>$inst_logfile
else
    echo "error: FFmpeg was not installed correctly" >>$inst_logfile
    echo "The installation was terminated due to an error during the installation of FFmpeg."
    exit
fi

```

## Teststream mit FFmpeg generieren
### rtmp-Stream
```
targetServer="rtmp://meineStreamServerIP/live/rtmpTest"
ffmpeg -r 30 -f lavfi -i testsrc -vf scale=1920:1080 -vcodec libx264 -profile:v baseline -pix_fmt yuv420p -f flv $targetServer
```
### srt-Stream
```
targetServer="srt://0.0.0.0:9999?mode=listener&pkt_size=1316"
ffmpeg -r 30 -f lavfi -i testsrc -vf scale=1920:1080 -vcodec libx264 -profile:v baseline -pix_fmt yuv420p -f mpegts $targetServer
```
Bei dieser Variante liegt der Teststream auf dem Server abrufbereit und kann mit vMix oder OBS, als SRT **caller** abgerufen werden.  
**Achtung:** Der hier verwendete Port 9999 muss in der Firewall für UDP-Verkehr freigegeben werden.  
Das SRT Protokoll bietet aber noch jede Menge weiterer Konfigurationsmöglichkeiten.  
- https://github.com/Haivision/srt/blob/master/docs/apps/srt-live-transmit.md  
- https://ffmpeg.org/ffmpeg-protocols.html#srt  

### weitere Varianten
```
# Textdatei, mit sich selbst aktualisierender Uhrzeit erzeugen:
while [ true ]; do date +%T,%1N > text.txt ; sleep 0.9 ;  done

# FFmpeg
targetserver="srt://0.0.0.0:9999?mode=listener&pkt_size=1316"
ffmpeg -v debug  -f lavfi -i smptehdbars=size=1920x1080:rate=30 -f lavfi -i sine=1000 -vf "drawtext=textfile=text.txt:reload=1:fontsize=120:fontcolor=white:x=1000:y=900"  -f mpegts $targetServer

```

## als Dienste (systemd) einrichten
Damit wird FFmpeg bei jedem Neustart des Servers gestartet und ausgeführt.
Im Beispiel fehlt aktuell allerdings noch jegliche Konfigurationsmöglchkeit! Das kommt später.  
Du kannst den Status der Dienste so abfragen:  
- `systemctl status rtmpStreamGenerate` oder 
- `systemctl status srtStreamGenerate`  
>Den **rtmp**-Teststream kannst du z.B. zu einem RestreamServer oder zu Youtube oder wohin du auch willst senden. Du musst nur die `rtmp://xxx.xxx.xxx.xxx/??/??` entsprechend anpassen.
>Der **srt**-Teststream liegt dagegen auf diesem Server bereit. Du kannst ihn z.B. mit OBS Studio so direkt abrufen:  
Eingabe: `srt://<die Server-IP dieses TestStreamGenerator>:9999?mode=caller`  
Eingabeformat: `mpegts`  
SRT benötigt einen UDP Port. Ich habe 9999 gewählt. Dieser Port muss hier auf dem Server geöffnet werden, damit SRT funktioniert.  

### rtmpStreamGenerate.service
`cd /etc/systemd/system`  
`sudo nano rtmpStreamGenerate.service`  

und Einfügen:  
```
[Unit]
Description=static rtmp testStream push to Stream Server

[Service]
Type=simple
After=network.target
Restart=always
RestartSec=20
ExecStart=/usr/local/bin/ffmpeg -r 30 -f lavfi -i testsrc -vf scale=1920:1080 -vcodec libx264 -profile:v baseline -pix_fmt yuv420p -f flv rtmp://meineStreamServerIP/live/rtmpTest

[Install]
WantedBy=multi-user.target
```   
"RestartSec=20" verwende ich, da mein RestreamServer schnelle Wiederverbindungsversuche blockiert.  
[Strg]+[o] und [Strg]+[x]

### srtStreamGenerate.service
`cd /etc/systemd/system`  
`sudo nano srtStreamGenerate.service`  

und Einfügen:  
```
[Unit]
Description=static srt listener testStream

[Service]
Type=simple
After=network.target
Restart=always
ExecStart=/usr/local/bin/ffmpeg -r 30 -f lavfi -i testsrc -vf scale=1920:1080 -vcodec libx264 -profile:v baseline -pix_fmt yuv420p -f mpegts 'srt://0.0.0.0:9999?mode=listener&pkt_size=1316'

[Install]
WantedBy=multi-user.target
```  
Der bei "srt://0.0.0.0:xxxx" verwendete Port muss für UDP Datenverkehr in der Firewall geöffnet sein!   
Wenn "pkt_size=1316" nicht angegeben wird, funktioniert OBS (manchmal) nicht (Stand 12/2021).  
[Strg]+[o] und [Strg]+[x]  


```
sudo systemctl daemon-reload  
# rtmp
sudo systemctl enable rtmpStreamGenerate
sudo systemctl start rtmpStreamGenerate
sudo systemctl status rtmpStreamGenerate
# srt
sudo systemctl enable srtStreamGenerate
sudo systemctl start srtStreamGenerate
sudo systemctl status srtStreamGenerate
``` 

# SRT zu HLS
```
ffmpeg SRT --> HLS --> Ausgabe auf Webseite mit video.js
```
## nginx und ffmpeg installieren
```
apt install nginx
apt install ffmpeg
```
### HTML Seite anlegen
`nano /var/www/html/hls.html`  
und Folgendes einfügen:   
```
<!DOCTYPE html>
<html lang="de">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link href="https://vjs.zencdn.net/7.19.2/video-js.css" rel="stylesheet" />
    <title>HTTP Live Streaming Example</title>
    </head>
    <body>
      <script src="https://vjs.zencdn.net/7.19.2/video.js"></script>
      <video
        id="my-player"
        class="video-js"
        controls="true"
        preload="auto"
        auto="true"
        width="480"
        height="270"
        data-setup='{}'>
        <source src="http://192.168.55.101/stream.m3u8" type="application/x-mpegURL"></source>
      </video>
    </body>
</html>
```
**Mein Server hat in diesem Beispiel die IP-Adresse: 192.168.55.101.**  
### Testbild mit Uhrzeit erzeugen
und mit ffmpeg in HLS umwandeln:  
#### Umweg über 'textfile=text.txt:reload=1', um Zehntelsekunden anzuzeigen
```
while [ true ]; do date +%T,%1N | tee /var/www/html/text.txt ; sleep 0.1; clear ;  done
```
```
torichter@webServer-1:/var/www/html$ rm stream*.*; ffmpeg -f lavfi -i smptehdbars=size=1920x1080:rate=120 -f lavfi -i sine=1000 -vf "drawtext=textfile=text.txt:reload=1:fontsize=120:fontcolor=white:x=1000:y=900" -c:v libx264 -g 60 -sc_threshold 0 -f hls -hls_time 2 stream.m3u8
```
#### mit Nutzung von '%{localtime}'   
Leider werden mir so nur die Sekunden angezeigt.  
```
torichter@webServer-1:/var/www/html$ rm stream*.*; ffmpeg -re -f lavfi -i smptehdbars=size=1920x1080:rate=60 -f lavfi -i sine=frequency=1000:sample_rate=48000 -vf "drawtext=fontsize=120:fontcolor=white:x=1000:y=900:text='%{localtime\:%T}'" -c:v libx264 -g 60 -sc_threshold 0 -f hls -hls_time 1 stream.m3u8
```
### Anzeige der Uhrzeit (Sekunden) und der Laufzeit des Streams (Millisekunden)
**und einen Beepton jede Sekunde** 
```
torichter@webServer-1:/var/www/html$ rm stream*.*; ffmpeg -re -f lavfi -i smptehdbars=size=1920x1080:rate=60 -f lavfi -i sine=frequency=1000:sample_rate=48000:beep_factor=4 -ac 2 -vf "drawtext=fontsize=140:fontcolor=white:x=1000:y=870:text='%{localtime\:%T}' , drawtext=fontsize=50:fontcolor=white:x=1000:y=1000:text='%{pts\\:hms}'"  -c:v libx264 -g 60 -sc_threshold 0 -f hls -hls_time 1 stream.m3u8
```

**Allerdings habe ich hier immer noch eine sehr große Verzögerung von fast 5 Sekunden.**  


Die Webseite kannst du dann so im Browser aufrufen:   
**`http://192.168.55.101/hls.html`**,    
oder so im VLC Media Player:  
**`http://192.168.55.101/stream.m3u8`**   


