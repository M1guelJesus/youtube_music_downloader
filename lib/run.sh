#!/bin/bash

run_downloader() {
    parse_args "$@"
    check_dependencies
    detect_cookies
    trap 'progress_finish; cleanup_cookies_tmp' EXIT

    if [[ "$DUMP_METADATA" != true ]]; then
        mkdir -p "$OUTPUT_DIR"
        log "Fetching catalog..."
    fi

    local catalog
    catalog="$(fetch_catalog "$INPUT_URL")" || die "Failed to fetch catalog"

    if [[ "$DUMP_METADATA" == true ]]; then
        dump_catalog_metadata "$catalog"
        exit 0
    fi

    local artist_name
    artist_name="$(catalog_field "$catalog" artist)"
    artist_name="$(sanitize_path "$artist_name")"

    log "Artist: $artist_name"
    print_catalog_summary "$catalog"

    if [[ "$DRY_RUN" == true ]]; then
        print_catalog_dry_run "$catalog"
        exit 0
    fi

    local tmp_dir="$OUTPUT_DIR/.tmp"
    mkdir -p "$tmp_dir"

    local -a tracks=()
    local line
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        tracks+=("$line")
    done < <(iter_catalog_tracks "$catalog")

    local total=${#tracks[@]}
    if (( total == 0 )); then
        log "No tracks to download"
        exit 0
    fi

    progress_start "$total"

    local downloaded=0
    local skipped=0
    local failed=0
    local -a failed_songs=()

    for line in "${tracks[@]}"; do
        local album_title video_id clean_title thumbnail_url
        album_title="${line%%$'\t'*}"
        local rest="${line#*$'\t'}"
        video_id="${rest%%$'\t'*}"
        rest="${rest#*$'\t'}"
        clean_title="${rest%%$'\t'*}"
        if [[ "$rest" == *$'\t'* ]]; then
            thumbnail_url="${rest#*$'\t'}"
        else
            thumbnail_url=""
        fi

        album_title="$(sanitize_path "$album_title")"
        clean_title="$(sanitize_path "$clean_title")"

        local dest_file="$OUTPUT_DIR/$artist_name/$album_title/${clean_title}.mp3"

        if is_archived "$video_id"; then
            log "Already archived, skipping: $clean_title"
            ((skipped++)) || true
            progress_update skipped "$clean_title"
            continue
        fi

        if [[ -e "$dest_file" ]]; then
            log "File already exists, skipping: $dest_file"
            mark_archived "$video_id"
            ((skipped++)) || true
            progress_update skipped "$clean_title"
            continue
        fi

        DOWNLOAD_ERROR=""
        if download_track \
            "$video_id" \
            "$dest_file" \
            "$tmp_dir" \
            "$artist_name" \
            "$album_title" \
            "$clean_title" \
            "$thumbnail_url"
        then
            mark_archived "$video_id"
            ((downloaded++)) || true
            log "Saved: $dest_file"
            progress_update downloaded "$clean_title"
        else
            ((failed++)) || true
            local error_msg="${DOWNLOAD_ERROR:-unknown error}"
            failed_songs+=("$album_title"$'\t'"$clean_title"$'\t'"$video_id"$'\t'"$error_msg")
            log "Failed (not archived): $clean_title ($video_id) — $error_msg"
            progress_update failed "$clean_title"
        fi
    done

    progress_finish
    rmdir "$tmp_dir" 2>/dev/null || true
    cleanup_cookies_tmp
    trap - EXIT

    log "Done. Downloaded: $downloaded, skipped: $skipped, failed: $failed"

    if (( failed > 0 )); then
        log "Failed songs (left out of archive so they can be retried):"
        local entry album song vid err
        for entry in "${failed_songs[@]}"; do
            album="${entry%%$'\t'*}"
            rest="${entry#*$'\t'}"
            song="${rest%%$'\t'*}"
            rest="${rest#*$'\t'}"
            vid="${rest%%$'\t'*}"
            err="${rest#*$'\t'}"
            printf '  - %s / %s (%s)\n    error: %s\n' "$album" "$song" "$vid" "$err" >&2
        done
        exit 1
    fi
}
