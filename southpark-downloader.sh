#!/usr/bin/env bash

# GNU hates him
export POSIXLY_CORRECT=1

# Resolve executable directory
DIR="$(dirname "$(readlink -f "$0")")"

source "$DIR/config.sh"

# Turn paths into absolute ones if they aren't already. Will be necessary since we'll change directories later.
[ ! "${CACHEDIR::1}" = "/" ] &&
	CACHEDIR="$DIR/$CACHEDIR"
[ ! "${OUTDIR::1}" = "/" ] &&
	OUTDIR="$DIR/$OUTDIR"
[ ! "${YOUTUBE_DL::1}" = "/" ] &&
	YOUTUBE_DL="$DIR/$YOUTUBE_DL"

[ ! -e "$OUTDIR" ] && mkdir -p "$OUTDIR"
[ ! -e "$CACHEDIR" ] && mkdir -p "$CACHEDIR"

# Initialize youtube-dlp if necessary
init() {
	local CUSTOM_PYTHON=

	if ! which python > /dev/null; then
		if which python3 > /dev/null; then
			echo ">>> python not found, using python3 instead"
			CUSTOM_PYTHON=python3
		else
			echo ">>> No python executable found, please install python or python3"
			exit 1
		fi
	fi

	if [ ! -e "$DIR/yt-dlp" ]; then
		echo ">>> Cloning youtube-dlp repo" &&
		git clone -c advice.detachedHead=false --depth 1 --branch "2023.03.04" "https://github.com/yt-dlp/yt-dlp.git" "$DIR/yt-dlp"
	fi

	echo ">>> Building youtube-dlp"
	make -C "$DIR/yt-dlp" yt-dlp
	[ -n "$CUSTOM_PYTHON" ] &&
		sed -i "1c\\#!/usr/bin/env $CUSTOM_PYTHON" "$DIR/yt-dlp"
}

p_info() {
	echo -e "\e[32m>>> $@\e[m"
}

p_error() {
	echo -e "\e[1;31m>>> $@\e[m"
}

usage() {
	echo "Usage:"
	echo "  $(basename "$0") [OPTIONS] -a                        -  Download all episodes"
	echo "  $(basename "$0") [OPTIONS] -s <season>               -  Download all episodes of the specified season"
	echo "  $(basename "$0") [OPTIONS] -s <season> -e <episode>  -  Download the specified episode"
	echo "  $(basename "$0") -h                                  -  Show help page"
	echo "Options:"
	echo " -p                                        -  Show progress (default)"
	echo " -P                                        -  Hide progress"
	echo " -E                                        -  Download episodes in English (default)"
	echo " -D                                        -  Download episodes in German"
	echo " -u                                        -  Update episode index (default)"
	echo " -U                                        -  Skip episode index update"
	echo " -d                                        -  Dry run: don't download, just print out URLs"
	echo " -i                                        -  Re-initialize yt-dlp"
}

unset DOING_SOMETHING
unset OPT_SEASON OPT_EPISODE OPT_ALL OPT_LANG OPT_PROGRESS OPT_UPDATE_INDEX OPT_DRY OPT_REINIT
OPT_LANG="EN"
OPT_PROGRESS=true
OPT_UPDATE_INDEX=true

while getopts "pPEDuUdais:e:h" arg; do
	case "$arg" in
		h)
			usage
			exit 0
			;;
		s)
			OPT_SEASON="$OPTARG"
			DOING_SOMETHING=true
			;;
		e)
			OPT_EPISODE="$OPTARG"
			DOING_SOMETHING=true
			;;
		a)
			OPT_ALL=true
			DOING_SOMETHING=true
			;;
		E)
			OPT_LANG="EN"
			;;
		D)
			OPT_LANG="DE"
			;;
		p)
			OPT_PROGRESS=true
			;;
		P)
			unset OPT_PROGRESS
			;;
		u)
			OPT_UPDATE_INDEX=true
			DOING_SOMETHING=true
			;;
		U)
			unset OPT_UPDATE_INDEX
			;;
		d)
			OPT_DRY=true
			;;
		i)
			OPT_REINIT=true
			DOING_SOMETHING=true
			;;
		?)
			usage
			exit 1
			;;
	esac
done

if [ "$OPT_LANG" = "DE" ]; then
	INDEX_FILENAME="$CACHEDIR/_episode_index_DE_"
	INDEX_INITIAL_URL="https://www.southpark.de/folgen/940f8z/south-park-cartman-und-die-analsonde-staffel-1-ep-1"
	REGEX_EPISODE_URL="/folgen/[0-9a-z]\\+/south-park-[0-9a-z-]\\+-staffel-[0-9]\\+-ep-[0-9]\\+"
elif [ "$OPT_LANG" = "EN" ]; then
	INDEX_FILENAME="$CACHEDIR/_episode_index_EN_"
	INDEX_INITIAL_URL="https://www.southpark.de/en/episodes/940f8z/south-park-cartman-gets-an-anal-probe-season-1-ep-1"
	REGEX_EPISODE_URL="/en/episodes/[0-9a-z]\\+/south-park-[0-9a-z-]\\+-season-[0-9]\\+-ep-[0-9]\\+"
fi

update_index() {
	[ ! -e "$INDEX_FILENAME" ] && echo "$INDEX_INITIAL_URL" > "$INDEX_FILENAME"
	echo -ne "\e[32m>>> Updating episode index\e[m"
	while true; do
		local SEEDURL="$(tail -n1 "$INDEX_FILENAME" | tr -d '\n')"
		local HTML="$(curl -s "$SEEDURL")"
		local URLS="$(echo -n "$HTML" | sed 's@</a>@|@g' | tr '|' '\n' | sed -n "s@.*href=\"\\($REGEX_EPISODE_URL\\)\".*@\\1@p" | sed "s@^@https://www.southpark.de@g" | tr '\n' '|')"
		# The sed command only retains all matches after the seed URL
		local NEWURLS="$(echo -n "$URLS" | tr '|' '\n' | sed -n "\\@^$SEEDURL\$@,\$p" | tail -n +2 | tr '\n' '|')"
		[ -z "$NEWURLS" ] && break
		echo -n "$NEWURLS" | tr '|' '\n' >> "$INDEX_FILENAME"
		echo -ne "\e[32m.\e[m"
	done
	echo
}

# Returns all episode URLs in the specified season
get_season() {
	local SEASON_NUMBER="$1"
	grep "\-${SEASON_NUMBER}-ep-[0-9]\+$" "$INDEX_FILENAME"
}

# Returns the URL of the specified episode
get_episode() {
	local SEASON_NUMBER="$1"
	local EPISODE_NUMBER="$2"
	grep "\-${SEASON_NUMBER}-ep-${EPISODE_NUMBER}$" "$INDEX_FILENAME"
}

get_num_seasons() {
	# Effectively searches, how many "episode 1s" there are in the index
	grep "\-[0-9]\+-ep-1$" "$INDEX_FILENAME" | wc -l
}

# Returns the number of episodes in the specified season
get_num_episodes() {
	local SEASON_NUMBER="$1"
	get_season "$SEASON_NUMBER" | wc -l
}

tmp_cleanup() {
	p_info "Cleaning up temporary files"
	rm -rf "$TMPDIR"
}

# Monitors size of downloaded video files; takes temp folder as arg
monitor_progress() {
	local TMP_DIR="$1"
	while true; do
		[ ! -e "$TMP_DIR" ] && break
		printf " Downloaded: %sMB\r" "$(du -m "$TMP_DIR" | cut -f1)"
		sleep 0.5
	done
}

download_interrupt() {
	p_info "User interrupt received"
	tmp_cleanup
	exit 0
}

merge_interrupt() {
	p_info "User interrupt received"
	tmp_cleanup
	p_info "Cleaning up corrupted output file"
	rm -rf "$1"
	exit 0
}

# Takes season and episode number as arguments
download_episode() {
	local SEASON_NUMBER="$1"
	local EPISODE_NUMBER="$2"
	local SEASON_STRING="$(printf "%02d" "$SEASON_NUMBER")"
	local EPISODE_STRING="$(printf "%02d" "$EPISODE_NUMBER")"
	local OUTFILE="${OUTDIR}/South_Park_${OPT_LANG}_S${SEASON_STRING}_E${EPISODE_STRING}.mp4"
	[ -e "$OUTFILE" ] && echo "Already downloaded Season ${SEASON_NUMBER} Episode ${EPISODE_NUMBER}" && return
	local URL="$(get_episode "$SEASON_NUMBER" "$EPISODE_NUMBER")"
	[ -z "$URL" ] && echo "Unable to download Season ${SEASON_NUMBER} Episode ${EPISODE_NUMBER}; skipping" && return
	p_info "Downloading Season $SEASON_NUMBER Episode $EPISODE_NUMBER ($URL)"
	if [ -z "$OPT_DRY" ]; then
	trap download_interrupt SIGINT
	TMPDIR="$(mktemp -d "/tmp/southparkdownloader.XXXXXXXXXX")"
	[ -n "$OPT_PROGRESS" ] && monitor_progress "$TMPDIR"&
	cd "$TMPDIR" > /dev/null
	if ! "$YOUTUBE_DL" "$URL" 2>/dev/null | sed -n '/^\[download\] Destination:/!p' | sed -n '/^\[download\]/p'; then
		p_info "possible youtube-dl \e[1;31mERROR\e[m"
		tmp_cleanup
		exit 1
	fi
	echo "[download] Merging video files"
	trap "merge_interrupt \"$OUTFILE\"" SIGINT
	# Remove all single quotes and dashes from video files, as they cause problems
	for i in ./*.mp4; do mv -n "$i" "$(echo $i | tr -d \'-)"; done
	# Find all video files and write them into the list
	printf "file '%s'\n" ./*.mp4 > list.txt
	# Merge video files
	ffmpeg -safe 0 -f concat -i "list.txt" -c copy "$OUTFILE" 2>/dev/null
	cd - > /dev/null
	trap - SIGINT
	fi
	tmp_cleanup
}

# Takes season number as an argument
download_season() {
	local SEASON_NUMBER="$1"
	local NUM_EPISODES="$(get_num_episodes "$SEASON_NUMBER")"
	for i in $(seq "$NUM_EPISODES"); do
		download_episode "$SEASON_NUMBER" "$i"
	done
}

download_all() {
	local NUM_SEASONS="$(get_num_seasons)"
	for i in $(seq "$NUM_SEASONS"); do
		download_season "$i"
	done
}

[ -z "$DOING_SOMETHING" ] && usage && exit 1

[ -n "$OPT_REINIT" ] &&
	[ "$YOUTUBE_DL" != "$DIR/./yt-dlp/yt-dlp" ] &&
	echo 'Please change YOUTUBE_DL back to "./yt-dlp/yt-dlp" in order to re-initialize'

if [ "$YOUTUBE_DL" = "$DIR/./yt-dlp/yt-dlp" ] &&
	[ ! -e "$DIR/yt-dlp" ] ||
	([ -n "$OPT_REINIT" ] && rm -rf "$DIR/yt-dlp")
then
	init
fi

if [ -n "$OPT_UPDATE_INDEX" ]; then
	update_index
fi

if [ -n "$OPT_EPISODE" ] && [ -z "$OPT_SEASON" ]; then
	echo "Season not specified, assuming season 1"
	OPT_SEASON=1
fi

if [ -n "$OPT_SEASON" ]; then
	[ -z "$(get_season $OPT_SEASON)" ] &&
		p_error "Unable to find Season $OPT_SEASON" &&
		exit 1
	if [ -n "$OPT_EPISODE" ]; then
		[ -z "$(get_episode $OPT_SEASON $OPT_EPISODE)" ] &&
			p_error "Unable to find Season $OPT_SEASON Episode $OPT_EPISODE" &&
			exit 1
		p_info "Going to download Season $OPT_SEASON Episode $OPT_EPISODE"
		download_episode "$OPT_SEASON" "$OPT_EPISODE"
	else
		p_info "Going to download Season $OPT_SEASON"
		download_season "$OPT_SEASON"
	fi
elif [ -n "$OPT_ALL" ]; then
	p_info "Going to download ALL episodes"
	download_all
fi
