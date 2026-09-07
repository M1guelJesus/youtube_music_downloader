"""Build a download catalog from a YouTube Music URL."""

from __future__ import annotations

import json
import sys

from ytmusicapi import YTMusic

from ytm_downloader.artist import fetch_artist_catalog
from ytm_downloader.playlist import fetch_playlist_catalog
from ytm_downloader.url import detect_url_type, resolve_artist_channel_id
from ytm_downloader.video import fetch_video_catalog


def fetch_catalog(url: str) -> dict:
    url_type, resource_id = detect_url_type(url)

    yt = YTMusic()
    seen_songs: set[str] = set()
    seen_video_ids: set[str] = set()

    if url_type == "artist":
        channel_id = resolve_artist_channel_id(yt, resource_id)
        return fetch_artist_catalog(yt, channel_id, seen_songs, seen_video_ids)
    if url_type == "playlist":
        return fetch_playlist_catalog(
            yt, resource_id, url, seen_songs, seen_video_ids
        )
    return fetch_video_catalog(yt, resource_id, url, seen_songs, seen_video_ids)


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: python -m ytm_downloader URL", file=sys.stderr)
        sys.exit(1)

    url = sys.argv[1]
    try:
        payload = fetch_catalog(url)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)

    json.dump(payload, sys.stdout)


if __name__ == "__main__":
    main()
