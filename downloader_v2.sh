#!/bin/bash
set -euo pipefail

###############################################################################
# YouTube Music downloader
#
# Automatically detects the URL type and downloads accordingly:
#   - Artist channel / @handle -> all studio albums
#   - Playlist                 -> entire playlist
#   - Single video             -> one track
#
# Organizes files as: {artist}/{album}/{song_name}.mp3}
#
# Usage:
#   ./downloader_v2.sh [OPTIONS] URL
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/utils.sh
source "$SCRIPT_DIR/lib/utils.sh"
# shellcheck source=lib/deps.sh
source "$SCRIPT_DIR/lib/deps.sh"
# shellcheck source=lib/download.sh
source "$SCRIPT_DIR/lib/download.sh"
# shellcheck source=lib/args.sh
source "$SCRIPT_DIR/lib/args.sh"
# shellcheck source=lib/catalog.sh
source "$SCRIPT_DIR/lib/catalog.sh"
# shellcheck source=lib/run.sh
source "$SCRIPT_DIR/lib/run.sh"

run_downloader "$@"
