# testStreamGenerator

# Ubuntu 20.04
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
Das Folgende kannst du in eine Skript einfügen, um zu prüfen, ob die Installation erfolgreich war.
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

## Teststream generieren
### rtmp-Stream
```
targetServer="rtmp://meineStreamServerIP/live/rtmpTest"
ffmpeg -r 30 -f lavfi -i testsrc -vf scale=1920:1080 -vcodec libx264 -profile:v baseline -pix_fmt yuv420p -f flv $targetServer
```
### srt-Stream
```
targetServer="rtmp://meineStreamServerIP/live/srtTest"
ffmpeg -r 30 -f lavfi -i testsrc -vf scale=1920:1080 -vcodec libx264 -profile:v baseline -pix_fmt yuv420p -f flv $targetServer
```

```
