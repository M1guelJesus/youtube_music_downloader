#!/bin/bash
set -u

###############################################################################
# Help
###############################################################################

usage() {
    cat <<EOF
Usage:
    $(basename "$0") [OPTIONS] [LINKS...]

Modes (Default - Run all):
    -d, --download              Download only
    -m, --convert               Normalize names, remove lives and remix videos and convert WEBM to MP3 only

Download options:
    -v, --video                 Download video instead of audio only
    -c, --cookies FILE          Cookies file for yt-dlp
    -f, --filters FILTERS       yt-dlp match filter
    -o, --output-template TMP   yt-dlp output template

Conversion options:
    -q, --quality QUALITY       MP3 VBR quality (0-9, lower is better)

General:
    -h, --help                  Show this help

Examples:

    Download audio:
        $(basename "$0") --download "URL"

    Download video:
        $(basename "$0") --download --video "URL"

    Download using cookies:
        $(basename "$0") --download --cookies cookies.txt "URL"

    Download with format filter:
        $(basename "$0") --download --filters 'title~=%cats%' "URL"

    Custom output:
        $(basename "$0") --download \\
            --output-template '%(artist)s/%(album)s/%(title)s.%(ext)s' \\
            "URL"

    Convert existing WEBM files:
        $(basename "$0") --convert

    Convert with highest quality:
        $(basename "$0") --convert --quality 0

    Complete workflow:
        $(basename "$0") --quality 0 "URL1" "URL2"
EOF
}

###############################################################################
# Download all files
###############################################################################

download_files() {
    local audio_only="$1"
    local cookies="$2"
    local filters="$3"
    local output_template="$4"
    shift 4
    local links=("$@")

    if (( ${#links[@]} == 0 )); then
        echo "Error: --download requires at least one URL." >&2
        exit 1
    fi

    for link in "${links[@]}"; do
        local current_output_template="$output_template"

        if [[ -z "$current_output_template" ]]; then
            if [[ "$link" == *"list="* ]]; then
                current_output_template="%(artist)s/%(album)s/%(title)s.%(ext)s"
            else
                current_output_template="%(artist)s/singles/%(title)s.%(ext)s"
            fi
        fi

        local format

        if [[ "$audio_only" == true ]]; then
            format='ba/b'
        else
            format='bv*+ba/b'
        fi

        echo
        echo "Downloading:"
        echo "  $link"
        echo "  Output: $current_output_template"
        echo

        local cmd=(
            youtube-dl
            -f "$format"
            -o "$current_output_template"
        )
        if [[ -n "$filters" ]]; then
            cmd+=(--match-filter "$filters")
        fi
        if [[ -n "$cookies" ]]; then
            cmd+=(--cookies "$cookies")
        fi
        cmd+=("$link")

        echo "${cmd[@]}"

        "${cmd[@]}"
    done
}

###############################################################################
# Delete files containing "Live" inside parentheses
###############################################################################

delete_live() {
    echo
    echo "Checking for files with the word 'Live'..."
    echo

    files=()

    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(
        find . -type f -regextype posix-extended \
            -regex '.*\([^)]*[Ll][Ii][Vv][Ee][^)]*\).*' \
            -print0
    )

    if (( ${#files[@]} == 0 )); then
        echo "No matching files found."
        return
    fi

    echo "The following files will be deleted:"
    echo

    printf '  %s\n' "${files[@]}"

    echo
    read -rp "Delete these ${#files[@]} files? [y/N] " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then

        for file in "${files[@]}"; do
            printf 'Deleting: %s\n' "$file"
            rm -- "$file"
        done

        echo
        echo "Deleted ${#files[@]} files."

    else
        echo "Cancelled. No files were deleted."
    fi
}

###############################################################################
# Delete files containing "Remix" inside parentheses
###############################################################################

delete_remix() {
    echo
    echo "Checking for files with the word 'Remix'..."
    echo

    files=()

    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(
        find . -type f -regextype posix-extended \
            -regex '.*\([^)]*[Rr][Ee][Mm][Ii][Xx][^)]*\).*' \
            -print0
    )

    if (( ${#files[@]} == 0 )); then
        echo "No matching files found."
        return
    fi

    echo "The following files will be deleted:"
    echo

    printf '  %s\n' "${files[@]}"

    echo
    read -rp "Delete these ${#files[@]} files? [y/N] " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then

        for file in "${files[@]}"; do
            printf 'Deleting: %s\n' "$file"
            rm -- "$file"
        done

        echo
        echo "Deleted ${#files[@]} files."

    else
        echo "Cancelled. No files were deleted."
    fi
}

###############################################################################
# Normalize filenames
###############################################################################

normalize() {
    echo
    echo "Normalizing filenames..."
    echo

    while IFS= read -r -d '' f; do

        dir="${f%/*}"
        name="${f##*/}"

        name="${name%.webm}"

        original_name="$name"

        # Remove [YouTube ID]
        name=$(printf '%s' "$name" |
            sed -E 's/[[:space:]]*\[[^]]*\]$//')

        # Remove (feat. ...)
        name=$(printf '%s' "$name" |
            sed -E 's/[[:space:]]*\(feat\.[^)]*\)//Ig')

        # Remove (Remastered)
        name=$(printf '%s' "$name" |
            sed -E 's/[[:space:]]*\(Remastered\)//Ig')

        # Normalize whitespace
        name=$(printf '%s' "$name" |
            sed -E 's/[[:space:]]+/ /g; s/^ +| +$//g')

        if [[ "$name" != "$original_name" ]]; then

            new_file="$dir/$name.webm"

            printf 'Renaming:\n'
            printf '  %s\n' "$f"
            printf '→ %s\n' "$new_file"

            if [[ -e "$new_file" ]]; then
                echo "WARNING: destination already exists, skipping."
                echo
                continue
            fi

            mv -- "$f" "$new_file"

            echo "✓ Renamed"
            echo
        fi

    done < <(find . -type f -iname '*.webm' -print0)
}

###############################################################################
# Convert WEBM → MP3
###############################################################################

convert() {
    local mp3_quality=$1

    echo
    echo "Converting files to MP3..."
    echo

    count=0
    failed=0

    while IFS= read -r -d '' file; do

        output="${file%.webm}.mp3"

        printf 'Converting:\n'
        printf '  %s\n' "$file"
        printf '  %s\n' "$output"

        if [[ ! -f "$file" ]]; then
            printf 'ERROR: Input file does not exist: %s\n\n' "$file" >&2
            ((failed++))
            continue
        fi

        if [[ -e "$output" ]]; then
            echo "WARNING: MP3 already exists, skipping."
            echo
            continue
        fi

        if ffmpeg \
            -nostdin \
            -hide_banner \
            -loglevel error \
            -i "$file" \
            -vn \
            -map_metadata 0 \
            -c:a libmp3lame \
            -q:a "$mp3_quality" \
            "$output"
        then

            rm -- "$file"

            echo "✓ Done"

            ((count++))

        else

            echo "✗ FAILED: $file" >&2

            rm -f -- "$output"

            ((failed++))

        fi

        echo

    done < <(find "$PWD" -type f -iname '*.webm' -print0)

    printf '%s\n' "================================"
    printf 'Conversion complete\n'
    printf 'Converted: %d\n' "$count"
    printf 'Failed:    %d\n' "$failed"
    printf '%s\n' "================================"
}

###############################################################################
# Argument parser
###############################################################################

if (( $# == 0 )); then
    usage
    exit 0
fi

run_convert=false
run_download=false
links=()
audio_only=true
cookies=""
filters=""
output_template=""
mp3_quality=0

while (( $# > 0 )); do

    case "$1" in

        -h|--help)
            usage
            exit 0
            ;;

        -d|--download)
            run_download=true
            ;;

        -m|--convert)
            run_convert=true
            ;;

        -v|--video)
            audio_only=false
            ;;

        -c|--cookies)
            if (( $# < 2 )); then
                echo "Error: --cookies requires a value." >&2
                exit 1
            fi
            cookies="$2"
            shift
            ;;

        -f|--filters)
            if (( $# < 2 )); then
                echo "Error: --filters requires a value." >&2
                exit 1
            fi
            filters="$2"
            shift
            ;;

        -o|--output-template)
            if (( $# < 2 )); then
                echo "Error: --output-template requires a value." >&2
                exit 1
            fi
            output_template="$2"
            shift
            ;;

        -q|--quality)

            if (( $# < 2 )); then
                echo "Error: --quality requires a value." >&2
                exit 1
            fi

            mp3_quality="$2"
            shift
            ;;


        -*)
            echo "Error: Unknown option: $1" >&2
            echo
            usage
            exit 1
            ;;

        *)
            # Anything that isn't an option is treated as a URL
            links+=("$1")
            ;;

    esac

    shift

done

###############################################################################
# Execute requested operations
###############################################################################

if [[ "$run_convert" == false && "$run_download" == false ]]; then
    run_convert=true
    run_download=true
fi

if ! [[ "$mp3_quality" =~ ^[0-9]$ ]] || (( "$mp3_quality" > 9 )); then
    echo "Error: quality must be between 0 and 9."
    exit 1
fi

if [[ -n "$cookies" && ! -f "$cookies" ]]; then
    echo "Error: Cookies file does not exist: $cookies" >&2
    exit 1
fi

if [[ "$run_download" == true ]]; then
    download_files \
        "$audio_only" \
        "$cookies" \
        "$filters" \
        "$output_template" \
        "${links[@]}" || exit 1
fi

if [[ "$run_convert" == true ]]; then
        delete_live
        delete_remix
        normalize
        convert "$mp3_quality"
fi

