"""Catalog output helpers for the bash wrapper."""

from __future__ import annotations

import json
import os
import sys


def load_catalog() -> dict:
    return json.loads(os.environ["CATALOG_JSON"])


def album_count(data: dict) -> int:
    return sum(1 for album in data["albums"] if album["title"] != "Singles")


def track_count(data: dict) -> int:
    return sum(len(album["tracks"]) for album in data["albums"])


def single_count(data: dict) -> int:
    singles = next((a for a in data["albums"] if a["title"] == "Singles"), None)
    return len(singles["tracks"]) if singles else 0


def print_summary(include_singles: bool) -> None:
    data = load_catalog()
    mode = data.get("mode", "artist")
    counts = {
        "album_count": album_count(data),
        "track_count": track_count(data),
        "single_count": single_count(data),
        "source_title": data.get("sourceTitle", ""),
    }

    if mode == "artist":
        print(f"Studio albums: {counts['album_count']}")
        if include_singles:
            print(f"Singles: {counts['single_count']}")
    elif mode == "playlist":
        print(f"Playlist: {counts['source_title']}")
        print(f"Tracks: {counts['track_count']}")
    elif mode == "video":
        print(f"Video: {counts['source_title']}")

    print(f"Unique tracks: {counts['track_count']}")


def print_dry_run() -> None:
    data = load_catalog()
    for album in data["albums"]:
        print(f"\nAlbum: {album['title']}")
        for track in album["tracks"]:
            print(f"  - {track['cleanTitle']} ({track['videoId']})")


def print_tracks() -> None:
    data = load_catalog()
    for album in data["albums"]:
        album_thumb = album.get("thumbnail") or ""
        for track in album["tracks"]:
            thumb = track.get("thumbnail") or album_thumb or ""
            print(
                f"{album['title']}\t{track['videoId']}\t{track['cleanTitle']}\t{thumb}"
            )


def print_metadata() -> None:
    print(json.dumps(load_catalog(), indent=2, ensure_ascii=False))


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python -m ytm_downloader.util COMMAND", file=sys.stderr)
        sys.exit(1)

    command = sys.argv[1]
    if command == "artist":
        print(load_catalog()["artist"])
    elif command == "mode":
        print(load_catalog().get("mode", "artist"))
    elif command == "source-title":
        print(load_catalog().get("sourceTitle", ""))
    elif command == "summary":
        include_singles = os.environ.get("INCLUDE_SINGLES", "false") == "true"
        print_summary(include_singles)
    elif command == "dry-run":
        print_dry_run()
    elif command == "tracks":
        print_tracks()
    elif command == "metadata":
        print_metadata()
    else:
        print(f"Unknown command: {command}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
