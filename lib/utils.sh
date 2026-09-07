#!/bin/bash

log() {
    printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" >&2
}

die() {
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
