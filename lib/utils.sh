#!/bin/bash

log() {
    printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" >&2
    progress_draw
}

die() {
    progress_finish
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

sanitize_path() {
    local value="$1"
    value="${value//$'\n'/ }"
    value="${value//$'\r'/ }"
    value=$(printf '%s' "$value" | sed -E 's/[\/\\:*?"<>|]/-/g; s/[[:space:]]+/ /g; s/^ +| +$//g')
    printf '%s' "$value"
}

is_archived() {
    local video_id="$1"
    [[ -f "$ARCHIVE_FILE" ]] && grep -Fxq "$video_id" "$ARCHIVE_FILE"
}

mark_archived() {
    local video_id="$1"
    mkdir -p "$(dirname "$ARCHIVE_FILE")"
    printf '%s\n' "$video_id" >> "$ARCHIVE_FILE"
}

PROGRESS_ACTIVE=false
PROGRESS_STICKY=false
PROGRESS_ROWS=0
PROGRESS_TOTAL=0
PROGRESS_DONE=0
PROGRESS_DOWNLOADED=0
PROGRESS_FAILED=0
PROGRESS_SKIPPED=0
PROGRESS_LABEL=""

_progress_tty() {
    [[ -t 2 ]]
}

_progress_rows() {
    local size
    if size="$(stty size </dev/tty 2>/dev/null)"; then
        printf '%s\n' "${size%% *}"
        return
    fi
    tput lines 2>/dev/null || printf '24\n'
}

_progress_build_line() {
    local left=$((PROGRESS_TOTAL - PROGRESS_DONE))
    (( left < 0 )) && left=0

    local cols=80
    local size
    if size="$(stty size </dev/tty 2>/dev/null)"; then
        cols="${size##* }"
    fi
    (( cols < 40 )) && cols=40

    local width=28
    local filled=0
    if (( PROGRESS_TOTAL > 0 )); then
        filled=$(( PROGRESS_DONE * width / PROGRESS_TOTAL ))
    fi
    (( filled > width )) && filled=$width

    local bar
    bar="$(printf '%*s' "$filled" '' | tr ' ' '#')"
    bar+="$(printf '%*s' "$((width - filled))" '' | tr ' ' '-')"

    local label="$PROGRESS_LABEL"
    local max_label=$(( cols - 55 ))
    (( max_label < 10 )) && max_label=10
    if (( ${#label} > max_label )); then
        label="${label:0:$((max_label - 3))}..."
    fi

    printf '[%s] %d/%d  downloaded:%d  failed:%d  left:%d%s' \
        "$bar" \
        "$PROGRESS_DONE" \
        "$PROGRESS_TOTAL" \
        "$PROGRESS_DOWNLOADED" \
        "$PROGRESS_FAILED" \
        "$left" \
        "${label:+  | $label}"
}

progress_start() {
    PROGRESS_ACTIVE=true
    PROGRESS_TOTAL="$1"
    PROGRESS_DONE=0
    PROGRESS_DOWNLOADED=0
    PROGRESS_FAILED=0
    PROGRESS_SKIPPED=0
    PROGRESS_LABEL="${2:-}"

    if _progress_tty; then
        PROGRESS_STICKY=true
        PROGRESS_ROWS="$(_progress_rows)"
        # Reserve the last terminal row for the progress bar.
        printf '\033[1;%dr' "$((PROGRESS_ROWS - 1))" >&2
        printf '\033[%d;1H' "$((PROGRESS_ROWS - 1))" >&2
    else
        PROGRESS_STICKY=false
    fi

    progress_draw
}

progress_update() {
    local kind="$1"
    local label="${2:-}"

    case "$kind" in
        downloaded) ((PROGRESS_DOWNLOADED++)) || true ;;
        failed) ((PROGRESS_FAILED++)) || true ;;
        skipped) ((PROGRESS_SKIPPED++)) || true ;;
    esac
    ((PROGRESS_DONE++)) || true
    PROGRESS_LABEL="$label"
    progress_draw
}

progress_draw() {
    [[ "$PROGRESS_ACTIVE" == true ]] || return 0

    local line
    line="$(_progress_build_line)"

    if [[ "$PROGRESS_STICKY" == true ]]; then
        local rows="$PROGRESS_ROWS"
        # Keep the bar pinned to the last row while logs scroll above it.
        printf '\0337' >&2
        printf '\033[%d;1H\033[K%s' "$rows" "$line" >&2
        printf '\0338' >&2
    else
        printf '%s\n' "$line" >&2
    fi
}

progress_finish() {
    [[ "$PROGRESS_ACTIVE" == true ]] || return 0

    if [[ "$PROGRESS_STICKY" == true ]]; then
        # Restore full-screen scrolling and leave the final bar as a normal line.
        printf '\033[r' >&2
        printf '\033[%d;1H\033[K' "$PROGRESS_ROWS" >&2
        printf '%s\n' "$(_progress_build_line)" >&2
        PROGRESS_STICKY=false
    elif [[ "$PROGRESS_ACTIVE" == true ]]; then
        printf '%s\n' "$(_progress_build_line)" >&2
    fi

    PROGRESS_ACTIVE=false
}
