#!/usr/bin/env sh
if [ -e yt-dlc/ ]; then
    echo ">>> youtube-dlc already downloaded, delete and redownload? [y/N]"
    read RES
    [ "$RES" = "y" ] || [ "$RES" = "Y" ] && rm -rf yt-dlc/
fi
if [ ! -e yt-dlc/ ]; then
    echo ">>> Cloning youtube-dlc repo" &&
    git clone --depth 1 --branch "2020.11.11-3" "https://github.com/blackjack4494/yt-dlc.git"
    echo ">>> Applying patches"
    # Allows for downloading English content from the German website
    patch -p0 < fix-southpark-de-en.diff
fi
echo ">>> Building youtube-dlc"
make -C yt-dlc/ youtube-dlc
