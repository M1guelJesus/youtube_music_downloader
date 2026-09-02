#!/bin/bash

run_downloader() {
    parse_args "$@"
    check_dependencies
    detect_cookies

    mkdir -p "$OUTPUT_DIR"

    log "Fetching catalog..."
    local catalog
    catalog="$(fetch_catalog "$INPUT_URL")" || die "Failed to fetch catalog"

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

    local downloaded=0
    local skipped=0
    local failed=0

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue

        local album_title video_id clean_title
        album_title="${line%%$'\t'*}"
        local rest="${line#*$'\t'}"
        video_id="${rest%%$'\t'*}"
        clean_title="${rest#*$'\t'}"

        album_title="$(sanitize_path "$album_title")"
        clean_title="$(sanitize_path "$clean_title")"

        local dest_file="$OUTPUT_DIR/$artist_name/$album_title/${clean_title}.mp3"

        if is_archived "$video_id"; then
            log "Already archived, skipping: $clean_title"
            ((skipped++)) || true
            continue
        fi

        if [[ -e "$dest_file" ]]; then
            log "File already exists, skipping: $dest_file"
            mark_archived "$video_id"
            ((skipped++)) || true
            continue
        fi

        if download_track "$video_id" "$dest_file" "$tmp_dir"; then
            mark_archived "$video_id"
            ((downloaded++)) || true
            log "Saved: $dest_file"
        else
            ((failed++)) || true
            log "Failed: $clean_title ($video_id)"
        fi
    done < <(iter_catalog_tracks "$catalog")

    rmdir "$tmp_dir" 2>/dev/null || true

    log "Done. Downloaded: $downloaded, skipped: $skipped, failed: $failed"
    (( failed == 0 )) || exit 1
}
