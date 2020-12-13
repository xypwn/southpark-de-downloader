# southpark-de-downloader
Effortlessly download South Park episodes from southpark.de in bulk

## Setup
`git clone https://github.com/xypwn/southpark-de-downloader.git; cd southpark-de-downloader`

`sh init.sh` this will download youtube-dlc and apply a patch for english episodes.

## Usage
`sh southpark-downloader.sh -h` to show usage instructions

All downloads will end up in the `downloads` folder in the cloned repo (you can also change it in config.sh, if you want to).

## Examples
`./southpark-downloader.sh -s 1` download all episodes of Season 1

`./southpark-downloader.sh -s 5 -e 13` download Season 5 Episode 13

`./southpark-downloader.sh -D -s 1` download Season 2 in German
