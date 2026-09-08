#!/bin/bash

download_track() {
    local video_id="$1"
    local dest_file="$2"
    local tmp_dir="$3"
    local artist_name="$4"
    local album_title="$5"
    local song_title="$6"
    local thumbnail_url="${7:-}"

    DOWNLOAD_ERROR=""

    mkdir -p "$tmp_dir" "$(dirname "$dest_file")"

    local output_template="$tmp_dir/${video_id}.%(ext)s"
    local watch_url="https://www.youtube.com/watch?v=${video_id}"
    local album_dir
    album_dir="$(dirname "$dest_file")"
    local cover_file="$album_dir/cover.jpg"
    local err_log
    err_log="$(mktemp)"

    log "Downloading: $video_id"

    local ok=false
    local last_ytdlp_error=""

    # Prefer no cookies. Only escalate to cookies for this and later tracks when
    # YouTube demands authentication.
    if [[ "$COOKIES_ENABLED" != true ]]; then
        if _download_with_clients "$watch_url" "$output_template" "$tmp_dir" "$video_id" "$err_log" \
            "youtube:player_client=android,web_embedded" \
            "youtube:player_client=tv,web_safari"
        then
            ok=true
        else
            last_ytdlp_error="$(_extract_ytdlp_error "$err_log")"
            if _error_needs_cookies "$last_ytdlp_error"; then
                if enable_cookies_for_run; then
                    log "Retrying this track with cookies..."
                else
                    DOWNLOAD_ERROR="${last_ytdlp_error}; no cookies configured"
                    log "Download failed without cookies. Re-run with --cookies-from-browser firefox"
                    rm -f -- "$err_log"
                    return 1
                fi
            else
                DOWNLOAD_ERROR="${last_ytdlp_error:-download failed}"
                rm -f -- "$err_log"
                return 1
            fi
        fi
    fi

    if [[ "$ok" != true && "$COOKIES_ENABLED" == true ]]; then
        if _download_with_clients "$watch_url" "$output_template" "$tmp_dir" "$video_id" "$err_log" \
            "youtube:player_client=web_embedded" \
            "youtube:player_client=mweb,web" \
            "youtube:player_client=web_safari,tv,web"
        then
            ok=true
        else
            last_ytdlp_error="$(_extract_ytdlp_error "$err_log")"
            DOWNLOAD_ERROR="${last_ytdlp_error:-download failed}"
            rm -f -- "$err_log"
            return 1
        fi
    fi

    if [[ "$ok" != true ]]; then
        DOWNLOAD_ERROR="${last_ytdlp_error:-download failed}"
        rm -f -- "$err_log"
        return 1
    fi

    local downloaded=""
    shopt -s nullglob
    local candidates=("$tmp_dir/${video_id}".*)
    shopt -u nullglob

    if (( ${#candidates[@]} == 0 )); then
        DOWNLOAD_ERROR="download produced no output file"
        log "Download failed for video $video_id (no output file)"
        rm -f -- "$err_log"
        return 1
    fi

    downloaded="${candidates[0]}"

    if [[ -n "$thumbnail_url" ]]; then
        download_thumbnail "$thumbnail_url" "$cover_file" || true
    fi

    : >"$err_log"
    if ! convert_to_mp3 \
        "$downloaded" \
        "$dest_file" \
        "$artist_name" \
        "$album_title" \
        "$song_title" \
        "$cover_file" \
        2> >(tee "$err_log" >&2)
    then
        DOWNLOAD_ERROR="mp3 conversion failed: $(_extract_ytdlp_error "$err_log")"
        [[ "$DOWNLOAD_ERROR" == "mp3 conversion failed: " ]] && DOWNLOAD_ERROR="mp3 conversion failed"
        rm -f -- "$err_log" "$downloaded"
        return 1
    fi

    rm -f -- "$downloaded" "$err_log"
    return 0
}

_download_with_clients() {
    local url="$1"
    local output_template="$2"
    local tmp_dir="$3"
    local video_id="$4"
    local err_log="$5"
    shift 5

    local client
    local attempted=false
    for client in "$@"; do
        if [[ "$attempted" == true ]]; then
            log "Retrying with different YouTube client..."
        fi
        attempted=true
        _cleanup_partials "$tmp_dir" "$video_id"
        : >"$err_log"
        if _yt_dlp_download "$url" "$output_template" "$client" 2> >(tee "$err_log" >&2); then
            return 0
        fi
    done
    return 1
}

_error_needs_cookies() {
    local err="$1"
    [[ -z "$err" ]] && return 1
    [[ "$err" == *"Sign in to confirm"* ]] && return 0
    [[ "$err" == *"sign in"* || "$err" == *"Sign in"* ]] && return 0
    [[ "$err" == *"--cookies"* ]] && return 0
    [[ "$err" == *"not a bot"* ]] && return 0
    [[ "$err" == *"login required"* || "$err" == *"Login required"* ]] && return 0
    return 1
}

_extract_ytdlp_error() {
    local log_file="$1"
    local err=""

    if [[ -s "$log_file" ]]; then
        err="$(grep -E '^ERROR:' "$log_file" | tail -n 1 | sed -E 's/^ERROR:[[:space:]]*//; s/^\[youtube\][[:space:]]*[A-Za-z0-9_-]+:[[:space:]]*//')"
        if [[ -z "$err" ]]; then
            err="$(grep -E '^(WARNING:|error:)' "$log_file" | tail -n 1 | sed -E 's/^(WARNING:|error:)[[:space:]]*//')"
        fi
        if [[ -z "$err" ]]; then
            err="$(tail -n 1 "$log_file" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
        fi
    fi

    printf '%s' "${err:-unknown error}"
}


_cleanup_partials() {
    local tmp_dir="$1"
    local video_id="$2"
    rm -f -- \
        "$tmp_dir/${video_id}".*.part \
        "$tmp_dir/${video_id}".*.ytdl \
        "$tmp_dir/${video_id}".*.frag* \
        "$tmp_dir/${video_id}".* 2>/dev/null || true
}

_yt_dlp_download() {
    local url="$1"
    local output_template="$2"
    local extractor_args="$3"

    local yt_dlp_args=(
        yt-dlp
        --no-update
        --no-playlist
        --no-overwrites
        --retries
        10
        --fragment-retries
        10
        --retry-sleep
        "fragment:exp=1:8"
        --skip-unavailable-fragments
        --js-runtimes
        "$YTDLP_JS_RUNTIME"
        --remote-components
        ejs:github
        # Prefer progressive HTTPS audio over fragile HLS/m3u8 streams.
        -f
        "bestaudio[protocol^=http][protocol!*=m3u8]/bestaudio[protocol^=http]/bestaudio/best"
        -S
        "+proto:https,aext:m4a,abr,res"
        --extractor-args
        "$extractor_args"
        -o
        "$output_template"
    )

    if [[ "$COOKIES_ENABLED" == true && -n "$COOKIES_FILE" ]]; then
        yt_dlp_args+=(--cookies "$COOKIES_FILE")
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
