#!/bin/bash

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] URL

Automatically detects the URL type:
  - Artist channel URL  -> downloads all studio albums
  - Artist @handle URL  -> resolves handle, then downloads studio albums
  - Playlist URL        -> downloads the entire playlist
  - Single video URL    -> downloads that one track

Files are saved as: {artist}/{album}/{song_name}.mp3}

Options:
    -o, --output-dir DIR    Output directory (default: ./downloads)
    -c, --cookies FILE      Cookies file for yt-dlp (auto-detected if omitted)
        --cookies-from-browser BROWSER
                            Load YouTube cookies from a browser profile
                            (e.g. firefox, chrome). Preferred over a stale
                            cookies export when YouTube asks you to sign in.
    -a, --archive FILE      Download archive file (default: .download_archive.txt)
    -q, --quality N         MP3 VBR quality 0-9, lower is better (default: 0)
    -s, --include-singles   Also download singles (saved under {artist}/Singles/)
    -n, --dry-run           List albums/tracks without downloading
    -m, --metadata-only     Dump catalog metadata as JSON and exit
    -h, --help              Show this help

Examples:
    $(basename "$0") "https://music.youtube.com/channel/UCqECaJ8Gagnn7YCbPEzWH6g"
    $(basename "$0") "https://music.youtube.com/@WrittenByWolves"
    $(basename "$0") "https://music.youtube.com/playlist?list=OLAK5uy_..."
    $(basename "$0") "https://music.youtube.com/watch?v=dQw4w9WgXcQ"
    $(basename "$0") -s "https://music.youtube.com/channel/UCqECaJ8Gagnn7YCbPEzWH6g"
    $(basename "$0") -m "https://music.youtube.com/@WrittenByWolves" > catalog.json
    $(basename "$0") -c cookies.txt -o ~/Music "https://music.youtube.com/watch?v=..."
EOF
}

parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -o|--output-dir)
                [[ $# -ge 2 ]] || die "--output-dir requires a value"
                OUTPUT_DIR="$2"
                shift
                ;;
            -c|--cookies)
                [[ $# -ge 2 ]] || die "--cookies requires a value"
                COOKIES_FILE="$2"
                shift
                ;;
            --cookies-from-browser)
                [[ $# -ge 2 ]] || die "--cookies-from-browser requires a value"
                COOKIES_FROM_BROWSER="$2"
                shift
                ;;
            -a|--archive)
                [[ $# -ge 2 ]] || die "--archive requires a value"
                ARCHIVE_FILE="$2"
                shift
                ;;
            -q|--quality)
                [[ $# -ge 2 ]] || die "--quality requires a value"
                MP3_QUALITY="$2"
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                ;;
            -m|--metadata-only)
                DUMP_METADATA=true
                ;;
            -s|--include-singles)
                INCLUDE_SINGLES=true
                ;;
            -*)
                die "Unknown option: $1"
                ;;
            *)
                if [[ -n "$INPUT_URL" ]]; then
                    die "Only one URL is supported"
                fi
                INPUT_URL="$1"
                ;;
        esac
        shift
    done

    [[ -n "$INPUT_URL" ]] || {
        usage
        exit 1
    }

    if ! [[ "$MP3_QUALITY" =~ ^[0-9]$ ]]; then
        die "Quality must be a single digit between 0 and 9"
    fi
}
