#!/bin/bash

download_track() {
    local video_id="$1"
    local dest_file="$2"
    local tmp_dir="$3"

    mkdir -p "$tmp_dir" "$(dirname "$dest_file")"

    local yt_dlp_args=(
        yt-dlp
        --no-update
        --no-playlist
        --no-overwrites
        --continue
        --retries
        10
        --fragment-retries
        10
        -f
        "ba/b"
        -o
        "$tmp_dir/${video_id}.%(ext)s"
    )

    if [[ -n "$COOKIES_FILE" ]]; then
        yt_dlp_args+=(--cookies "$COOKIES_FILE")
        yt_dlp_args+=(--extractor-args "youtube:player_client=web,web_music,tv_embedded")
    else
        yt_dlp_args+=(--extractor-args "youtube:player_client=android,web")
    fi

    yt_dlp_args+=("https://music.youtube.com/watch?v=${video_id}")

    log "Downloading: $video_id"
    if ! "${yt_dlp_args[@]}"; then
        return 1
    fi

    local downloaded=""
    shopt -s nullglob
    local candidates=("$tmp_dir/${video_id}".*)
    shopt -u nullglob

    if (( ${#candidates[@]} == 0 )); then
        log "Download failed for video $video_id (no output file)"
        return 1
    fi

    downloaded="${candidates[0]}"
    if ! convert_to_mp3 "$downloaded" "$dest_file"; then
        return 1
    fi

    rm -f -- "$downloaded"
    return 0
}

convert_to_mp3() {
    local input_file="$1"
    local output_file="$2"

    if [[ -e "$output_file" ]]; then
        log "Already exists, skipping conversion: $output_file"
        return 0
    fi

    local ext="${input_file##*.}"
    ext="${ext,,}"

    if [[ "$ext" == "mp3" ]]; then
        mv -- "$input_file" "$output_file"
        return 0
    fi

    log "Converting to MP3: $(basename "$output_file")"
    if ffmpeg \
        -nostdin \
        -hide_banner \
        -loglevel error \
        -i "$input_file" \
        -vn \
        -map_metadata 0 \
        -c:a libmp3lame \
        -q:a "$MP3_QUALITY" \
        "$output_file"
    then
        return 0
    fi

    rm -f -- "$output_file"
    return 1
}
