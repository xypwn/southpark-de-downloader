#!/usr/bin/env sh

source "$(dirname $0)/config.sh"

[ ! -e "$(dirname $0)/$OUTDIR" ] && mkdir -p "$(dirname $0)/$OUTDIR"

# Turn paths into absolute ones, if they aren't already, as we will change directories later
[ ! "${SAVEDIR::1}" = "/" ] &&
    OUTDIR="$(readlink -f $(dirname $0)/$OUTDIR)"
[ ! "${YOUTUBE_DL::1}" = "/" ] && 
    YOUTUBE_DL="$(readlink -f $(dirname $0)/$YOUTUBE_DL)"

p_info() {
    echo -e "\e[32m>>> $@\e[m"
}

p_error() {
    echo -e "\e[1;31m>>> $@\e[m"
}

usage() {
    echo "Usage:"
    echo "  $(basename $0) [-E|-D] -a                        -  Download all episodes"
    echo "  $(basename $0) [-E|-D] -s <season>               -  Download all episodes in the specified season"
    echo "  $(basename $0) [-E|-D] -s <season> -e <episode>  -  Download the specified episode"
    echo "Options:"
    echo " -E                                        -  Download episodes in English (default)"
    echo " -D                                        -  Download episodes in German"
}

unset OPT_SEASON OPT_EPISODE OPT_ALL OPT_EN OPT_LANG
OPT_LANG="EN"

while getopts "haEDs:e:" arg; do
    case "$arg" in
	h)
	    usage
	    exit 0
	    ;;
	s)
	    OPT_SEASON="$OPTARG"
	    ;;
	e)
	    OPT_EPISODE="$OPTARG"
	    ;;
	a)
	    OPT_ALL=true
	    ;;
	E)
	    OPT_LANG="EN"
	    ;;
	D)
	    OPT_LANG="DE"
	    ;;
	?)
	    echo "Invalid option: -$OPTARG"
	    usage
	    exit 1
	    ;;
    esac
done

# Parts of the URL differ depending on the language of the website
if [ "$OPT_LANG" = "DE" ]; then
    SEASON_1_URL="https://www.southpark.de/seasons/south-park/yjy8n9/staffel-1"
    REGEX_SEASON_URL="\"/seasons/south-park/[0-9a-z]\+/staffel-[0-9]\+\""
    REGEX_EPISODE_URL="\"/folgen/[0-9a-z]\+/south-park-[0-9a-z-]\+-staffel-[0-9]\+-ep-[0-9]\+\"" 
elif [ "$OPT_LANG" = "EN" ]; then
    SEASON_1_URL="https://www.southpark.de/en/seasons/south-park/yjy8n9/season-1"
    REGEX_SEASON_URL="\"/en/seasons/south-park/[0-9a-z]\+/season-[0-9]\+\""
    REGEX_EPISODE_URL="\"/en/episodes/[0-9a-z]\+/south-park-[0-9a-z-]\+-season-[0-9]\+-ep-[0-9]\+\"" 
fi

# Indexes all season page URLs
index_seasons() {
    # Get all season URLs by matching the regex
    SEASON_URLS=$(curl -s "$SEASON_1_URL" | grep -o "$REGEX_SEASON_URL" | tr -d "\"" | sed -E "s/^/https:\/\/www.southpark.de/g")
}

# Indexes all episode URLs of the currently indexed season (can only index 1 season at once, for now)
index_episodes() {
    local SEASON_NUMBER="$1"
    get_season_url "$SEASON_NUMBER"
    local SEASON_URL="$RES"
    EPISODE_URLS=$(curl -s "$SEASON_URL" | grep -o "$REGEX_EPISODE_URL" | tr -d "\"" | sed -E "s/^/https:\/\/www.southpark.de/g")
    INDEXED_SEASON="$SEASON_NUMBER"
}

################
# All functions named get_<something> store their result in the RES variable.
# We're not using command substitution, because then these functions couldn't set variables.
################
get_season_url() {
    local SEASON_NUMBER="$1"
    [ -z "$SEASON_URLS" ] && index_seasons
    RES=$(echo "$SEASON_URLS" | grep "\-${SEASON_NUMBER}$")
}

get_episode_url() {
    local SEASON_NUMBER="$1"
    local EPISODE_NUMBER="$2"
    [ ! "$INDEXED_SEASON" = "$SEASON_NUMBER" ] && index_episodes "$SEASON_NUMBER"
    RES=$(echo "$EPISODE_URLS" | grep "ep-${EPISODE_NUMBER}$")
}

get_num_seasons() {
    [ -z "$SEASON_URLS" ] && index_seasons
    RES=$(echo "$SEASON_URLS" | wc -l)
}

get_num_episodes() {
    local SEASON_NUMBER="$1"
    [ ! "$INDEXED_SEASON" = "$SEASON_NUMBER" ] && index_episodes "$SEASON_NUMBER"
    RES=$(echo "$EPISODE_URLS" | wc -l)
}

tmp_cleanup() {
    p_info "Cleaning up temporary files"
    rm -rf "$TMPDIR"
}

# Takes season and episode number as arguments
download_episode() {
    local SEASON_NUMBER="$1"
    local EPISODE_NUMBER="$2"
    get_episode_url "$SEASON_NUMBER" "$EPISODE_NUMBER"
    local URL="$RES"
    local OUTFILE="${OUTDIR}/South_Park_S${SEASON_NUMBER}_E${EPISODE_NUMBER}_${OPT_LANG}.mp4"
    [ -e "$OUTFILE" ] && echo "Already downloaded Season ${SEASON_NUMBER} Episode ${EPISODE_NUMBER}" && return
    p_info "Downloading Season $SEASON_NUMBER Episode $EPISODE_NUMBER ($URL)"
    TMPDIR=$(mktemp -d "/tmp/southparkdownloader.XXXXXXXXXX")
    pushd "$TMPDIR" > /dev/null
    if ! "$YOUTUBE_DL" "$URL" 2>/dev/null | grep --line-buffered "^\[download\]" | grep -v --line-buffered "^\[download\] Destination:"; then
	p_info "possible youtube-dl \e[1;31mERROR\e[m"
	tmp_cleanup
	exit 1
    fi
    echo "[download] Merging video files"
    # Remove all single quotes from video files, as they cause problems
    for i in ./*.mp4; do mv -n "$i" "$(echo $i | tr -d \')"; done
    # Find all video files and write them into the list
    printf "file '%s'\n" ./*.mp4 > list.txt
    # Merge video files
    ffmpeg -safe 0 -f concat -i "list.txt" -c copy "$OUTFILE" 2>/dev/null
    popd > /dev/null
    tmp_cleanup
}

# Takes season number as an argument
download_season() {
    local SEASON_NUMBER="$1"
    get_num_episodes "$SEASON_NUMBER"
    local NUM_EPISODES="$RES"
    for i in $(seq "$NUM_EPISODES"); do
	download_episode "$SEASON_NUMBER" "$i"
    done
}

download_all() {
    get_num_seasons
    local NUM_SEASONS="$RES"
    for i in $(seq "$NUM_SEASONS"); do
	download_season "$i"
    done
}

if [ -n "$OPT_SEASON" ]; then
    get_season_url "$OPT_SEASON"
    [ -z "$RES" ] &&
	p_error "Unable to open Season $OPT_SEASON" &&
	exit 1
    if [ -n "$OPT_EPISODE" ]; then
	get_episode_url "$OPT_SEASON" "$OPT_EPISODE"
	[ -z "$RES" ] &&
	    p_error "Unable to open Season $OPT_SEASON Episode $OPT_EPISODE" &&
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
else
    usage
    exit 1
fi
