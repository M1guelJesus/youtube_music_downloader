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

have_cookies() {
    [[ -n "$COOKIES_FROM_BROWSER" || -n "$COOKIES_FILE" ]]
}

extract_browser_cookies_once() {
    local browser="$1"
    local dest="$2"

    log "Extracting cookies from $browser (once for this run)..."
    printf '%s\n\n' '# Netscape HTTP Cookie File' > "$dest"

    # yt-dlp writes cookies to --cookies when also given --cookies-from-browser.
    # Ignore the probe URL result; we only care that a logged-in cookie jar was saved.
    yt-dlp \
        --no-update \
        --cookies-from-browser "$browser" \
        --cookies "$dest" \
        --skip-download \
        --no-warnings \
        "https://www.youtube.com/watch?v=jNQXAC9IVRw" >/dev/null 2>&1 || true

    if ! cookies_look_logged_in "$dest"; then
        rm -f -- "$dest"
        return 1
    fi
    return 0
}

enable_cookies_for_run() {
    if [[ "$COOKIES_ENABLED" == true ]]; then
        return 0
    fi
    if ! have_cookies; then
        return 1
    fi

    if [[ -n "$COOKIES_FROM_BROWSER" ]]; then
        COOKIES_TMP_FILE="$(mktemp "$SCRIPT_DIR/.cookies-run.XXXXXX")"
        if ! extract_browser_cookies_once "$COOKIES_FROM_BROWSER" "$COOKIES_TMP_FILE"; then
            rm -f -- "$COOKIES_TMP_FILE"
            COOKIES_TMP_FILE=""
            log "Failed to extract logged-in cookies from browser: $COOKIES_FROM_BROWSER"
            return 1
        fi
        COOKIES_FILE="$COOKIES_TMP_FILE"
        log "Cached browser cookies to temporary file for the rest of this run"
    elif [[ -n "$COOKIES_FILE" ]]; then
        if ! cookies_look_logged_in "$COOKIES_FILE"; then
            log "Cookies file looks logged-out: $COOKIES_FILE"
            return 1
        fi
        log "YouTube requires authentication; enabling cookies for the rest of this run: $COOKIES_FILE"
    fi

    COOKIES_ENABLED=true
}

cleanup_cookies_tmp() {
    if [[ -n "$COOKIES_TMP_FILE" && -f "$COOKIES_TMP_FILE" ]]; then
        rm -f -- "$COOKIES_TMP_FILE"
    fi
    COOKIES_TMP_FILE=""
}

detect_cookies() {
    COOKIES_ENABLED=false
    COOKIES_TMP_FILE=""

    if [[ -n "$COOKIES_FROM_BROWSER" ]]; then
        log "Cookies from browser ready as fallback: $COOKIES_FROM_BROWSER"
        log "Will download without cookies first; extract browser cookies only if YouTube requires sign-in"
        return
    fi

    if [[ -n "$COOKIES_FILE" ]]; then
        [[ -f "$COOKIES_FILE" ]] || die "Cookies file not found: $COOKIES_FILE"
        if ! cookies_look_logged_in "$COOKIES_FILE"; then
            die "Cookies file looks logged-out (no LOGIN_INFO/SID). Export while signed into YouTube, or use --cookies-from-browser firefox"
        fi
        log "Cookies file ready as fallback: $COOKIES_FILE"
        log "Will download without cookies first; enable them only if YouTube requires sign-in"
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
                log "Cookies file ready as fallback: $COOKIES_FILE"
                log "Will download without cookies first; enable them only if YouTube requires sign-in"
                return
            fi
            log "Ignoring logged-out cookies file: $candidate"
        fi
    done

    log "No usable cookies found; downloads may fail the YouTube bot check"
    log "Tip: ./downloader_v2.sh --cookies-from-browser firefox URL"
}
