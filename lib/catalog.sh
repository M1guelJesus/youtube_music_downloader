#!/bin/bash

fetch_catalog() {
    local url="$1"

    INCLUDE_SINGLES="$INCLUDE_SINGLES" COOKIES_FILE="$COOKIES_FILE" \
        PYTHONPATH="$SCRIPT_DIR" python3 -m ytm_downloader "$url"
}

catalog_field() {
    local catalog="$1"
    local field="$2"

    CATALOG_JSON="$catalog" PYTHONPATH="$SCRIPT_DIR" \
        python3 -m ytm_downloader.util "$field"
}

print_catalog_summary() {
    local catalog="$1"

    CATALOG_JSON="$catalog" INCLUDE_SINGLES="$INCLUDE_SINGLES" PYTHONPATH="$SCRIPT_DIR" \
        python3 -m ytm_downloader.util summary | while IFS= read -r line; do
        log "$line"
    done
}

print_catalog_dry_run() {
    local catalog="$1"

    CATALOG_JSON="$catalog" PYTHONPATH="$SCRIPT_DIR" \
        python3 -m ytm_downloader.util dry-run
}

iter_catalog_tracks() {
    local catalog="$1"

    CATALOG_JSON="$catalog" PYTHONPATH="$SCRIPT_DIR" \
        python3 -m ytm_downloader.util tracks
}
