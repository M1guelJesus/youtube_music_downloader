#!/bin/bash

download_track() {
    local video_id="$1"
    local dest_file="$2"
    local tmp_dir="$3"
    local artist_name="$4"
    local album_title="$5"
    local song_title="$6"
    local thumbnail_url="${7:-}"

    mkdir -p "$tmp_dir" "$(dirname "$dest_file")"

    local output_template="$tmp_dir/${video_id}.%(ext)s"
    local watch_url="https://www.youtube.com/watch?v=${video_id}"
    local album_dir
    album_dir="$(dirname "$dest_file")"
    local cover_file="$album_dir/cover.jpg"

    log "Downloading: $video_id"

    # Prefer android: it usually exposes a real audio stream without PO tokens.
    # Cookies force web clients and often leave only image formats.
    if ! _yt_dlp_download "$watch_url" "$output_template" \
        "youtube:player_client=android" ""
    then
        if [[ -n "$COOKIES_FILE" ]]; then
            log "Retrying with cookies..."
            if ! _yt_dlp_download "$watch_url" "$output_template" \
                "youtube:player_client=tv,web" "$COOKIES_FILE"
            then
                return 1
            fi
        else
            return 1
        fi
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

    if [[ -n "$thumbnail_url" ]]; then
        download_thumbnail "$thumbnail_url" "$cover_file" || true
    fi

    if ! convert_to_mp3 \
        "$downloaded" \
        "$dest_file" \
        "$artist_name" \
        "$album_title" \
        "$song_title" \
        "$cover_file"
    then
        return 1
    fi

    rm -f -- "$downloaded"
    return 0
}

_yt_dlp_download() {
    local url="$1"
    local output_template="$2"
    local extractor_args="$3"
    local cookies="$4"

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
        "bestaudio/best"
        --extractor-args
        "$extractor_args"
        -o
        "$output_template"
    )

    if [[ -n "$cookies" ]]; then
        yt_dlp_args+=(--cookies "$cookies")
    fi

    yt_dlp_args+=("$url")
    "${yt_dlp_args[@]}"
}

download_thumbnail() {
    local url="$1"
    local dest="$2"

    if [[ -z "$url" || -e "$dest" ]]; then
        return 0
    fi

    log "Downloading cover: $(basename "$(dirname "$dest")")/cover.jpg"
    if curl -fsSL --retry 3 --retry-delay 1 -o "$dest" "$url"; then
        return 0
    fi

    rm -f -- "$dest"
    return 1
}

convert_to_mp3() {
    local input_file="$1"
    local output_file="$2"
    local artist_name="${3:-}"
    local album_title="${4:-}"
    local song_title="${5:-}"
    local cover_file="${6:-}"

    if [[ -e "$output_file" ]]; then
        log "Already exists, skipping conversion: $output_file"
        return 0
    fi

    local ext="${input_file##*.}"
    ext="${ext,,}"

    log "Converting to MP3: $(basename "$output_file")"

    local ffmpeg_args=(
        ffmpeg
        -nostdin
        -hide_banner
        -loglevel error
    )

    if [[ -n "$cover_file" && -f "$cover_file" ]]; then
        ffmpeg_args+=(
            -i "$input_file"
            -i "$cover_file"
            -map 0:a:0
            -map 1:0
            -c:a libmp3lame
            -q:a "$MP3_QUALITY"
            -c:v mjpeg
            -id3v2_version 3
            -metadata:s:v title="Album cover"
            -metadata:s:v comment="Cover (front)"
            -disposition:v:0 attached_pic
        )
    else
        if [[ "$ext" == "mp3" ]]; then
            mv -- "$input_file" "$output_file"
            _write_text_metadata "$output_file" "$artist_name" "$album_title" "$song_title" || true
            return 0
        fi

        ffmpeg_args+=(
            -i "$input_file"
            -vn
            -c:a libmp3lame
            -q:a "$MP3_QUALITY"
        )
    fi

    if [[ -n "$song_title" ]]; then
        ffmpeg_args+=(-metadata "title=$song_title")
    fi
    if [[ -n "$artist_name" ]]; then
        ffmpeg_args+=(-metadata "artist=$artist_name")
    fi
    if [[ -n "$album_title" ]]; then
        ffmpeg_args+=(-metadata "album=$album_title")
    fi

    ffmpeg_args+=(-map_metadata 0 "$output_file")

    if "${ffmpeg_args[@]}"; then
        return 0
    fi

    rm -f -- "$output_file"
    return 1
}

_write_text_metadata() {
    local output_file="$1"
    local artist_name="$2"
    local album_title="$3"
    local song_title="$4"
    local tmp_file="${output_file}.meta.tmp.mp3"

    local ffmpeg_args=(
        ffmpeg
        -nostdin
        -hide_banner
        -loglevel error
        -i "$output_file"
        -c copy
        -map_metadata 0
        -id3v2_version 3
    )

    if [[ -n "$song_title" ]]; then
        ffmpeg_args+=(-metadata "title=$song_title")
    fi
    if [[ -n "$artist_name" ]]; then
        ffmpeg_args+=(-metadata "artist=$artist_name")
    fi
    if [[ -n "$album_title" ]]; then
        ffmpeg_args+=(-metadata "album=$album_title")
    fi

    ffmpeg_args+=("$tmp_file")

    if "${ffmpeg_args[@]}"; then
        mv -- "$tmp_file" "$output_file"
        return 0
    fi

    rm -f -- "$tmp_file"
    return 1
}
