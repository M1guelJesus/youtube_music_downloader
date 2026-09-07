#!/bin/bash

check_dependencies() {
    local missing=()
    for cmd in yt-dlp ffmpeg python3 curl; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done

    if (( ${#missing[@]} > 0 )); then
        die "Missing required commands: ${missing[*]}"
    fi

    if ! PYTHONPATH="$SCRIPT_DIR" python3 -c 'import ytm_downloader; import ytmusicapi' 2>/dev/null; then
        die "Python package 'ytmusicapi' is required. Install with: pip install ytmusicapi"
    fi
}

detect_cookies() {
    if [[ -n "$COOKIES_FILE" ]]; then
        [[ -f "$COOKIES_FILE" ]] || die "Cookies file not found: $COOKIES_FILE"
        return
    fi

    for candidate in \
        "$SCRIPT_DIR/cookies-youtube-com.txt" \
        "$SCRIPT_DIR/cookies.txt"
    do
        if [[ -f "$candidate" ]]; then
            COOKIES_FILE="$candidate"
            log "Using cookies: $COOKIES_FILE"
            return
        fi
    done

    log "No cookies file found; continuing without authentication"
}
