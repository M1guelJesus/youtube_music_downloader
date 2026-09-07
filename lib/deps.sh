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

    detect_js_runtime
}

detect_js_runtime() {
    # yt-dlp needs an external JS runtime to solve YouTube challenges (EJS).
    # Deno is preferred/default in yt-dlp; Node must be opted in explicitly.
    if command -v deno >/dev/null 2>&1; then
        YTDLP_JS_RUNTIME="deno"
    elif command -v node >/dev/null 2>&1; then
        YTDLP_JS_RUNTIME="node"
    else
        die "A JavaScript runtime is required for YouTube downloads (deno or node). Install one, then retry."
    fi
}

cookies_look_logged_in() {
    local file="$1"
    # Visitor-only exports (PREF/SOCS/VISITOR_*) cannot pass the bot check.
    awk -F '\t' '
        NF >= 7 && $1 !~ /^#/ {
            if ($6 ~ /^(LOGIN_INFO|SID|__Secure-1PSID|__Secure-3PSID|SAPISID|__Secure-1PSIDTS)$/) {
                found = 1
                exit
            }
        }
        END { exit found ? 0 : 1 }
    ' "$file"
}

detect_cookies() {
    if [[ -n "$COOKIES_FROM_BROWSER" ]]; then
        log "Using cookies from browser: $COOKIES_FROM_BROWSER"
        return
    fi

    if [[ -n "$COOKIES_FILE" ]]; then
        [[ -f "$COOKIES_FILE" ]] || die "Cookies file not found: $COOKIES_FILE"
        if ! cookies_look_logged_in "$COOKIES_FILE"; then
            die "Cookies file looks logged-out (no LOGIN_INFO/SID). Export while signed into YouTube, or use --cookies-from-browser firefox"
        fi
        return
    fi

    for candidate in \
        "$SCRIPT_DIR/cookies-www-youtube-com.txt" \
        "$SCRIPT_DIR/cookies-youtube-com.txt" \
        "$SCRIPT_DIR/cookies.txt"
    do
        if [[ -f "$candidate" ]]; then
            if cookies_look_logged_in "$candidate"; then
                COOKIES_FILE="$candidate"
                log "Using cookies: $COOKIES_FILE"
                return
            fi
            log "Ignoring logged-out cookies file: $candidate"
        fi
    done

    log "No usable cookies found; downloads may fail the YouTube bot check"
    log "Tip: ./downloader_v2.sh --cookies-from-browser firefox URL"
}
