#!/usr/bin/env sh

CUSTOM_PYTHON=

if ! which python > /dev/null; then
	if which python3 > /dev/null; then
		echo ">>> python not found, using python3 instead"
		CUSTOM_PYTHON=python3
	else
		echo ">>> No python executable found, please install python or python3"
		exit 1
	fi
fi

if [ -e yt-dlc/ ]; then
	printf ">>> youtube-dlc already downloaded, delete and redownload? [y/N]: "
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
[ -n "$CUSTOM_PYTHON" ] &&
	sed -i "1c\\#!/usr/bin/env $CUSTOM_PYTHON" yt-dlc/youtube-dlc
