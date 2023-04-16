# southpark-de-downloader
Effortlessly download South Park episodes from southpark.de in bulk

## Setup
`git clone https://git.nobrain.org/r4/southpark-de-downloader.git; cd southpark-de-downloader`

On the first run, it will download [yt-dlp](https://github.com/yt-dlp/yt-dlp). If you don't want this / already have yt-dlp, you can set your own path in `config.sh`.

## Usage
`./southpark-downloader.sh -h` to show usage instructions

All downloads will end up in the `downloads` folder in the cloned repo (you can also change it in config.sh, if you want to).

## Examples
`./southpark-downloader.sh -s 1` download all episodes of Season 1

`./southpark-downloader.sh -s 5 -e 13` download Season 5 Episode 13

`./southpark-downloader.sh -D -s 2` download Season 2 in German
