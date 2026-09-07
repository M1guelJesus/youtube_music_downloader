"""Artist catalog fetching."""

from __future__ import annotations

import os

from ytmusicapi import YTMusic

from ytm_downloader.tracks import collect_tracks, get_all_releases
from ytm_downloader.thumbnails import best_thumbnail

INCLUDE_SINGLES = os.environ.get("INCLUDE_SINGLES", "false") == "true"


def fetch_artist_catalog(
    yt: YTMusic,
    channel_id: str,
    seen_songs: set[str],
    seen_video_ids: set[str],
) -> dict:
    artist = yt.get_artist(channel_id)
    artist_name = artist.get("name") or "Unknown Artist"
    artist_thumbnail = best_thumbnail(artist.get("thumbnails"))

    albums_out = []

    for album_meta in get_all_releases(yt, artist, "albums"):
        album = collect_tracks(
            yt, artist_name, album_meta, "", seen_songs, seen_video_ids
        )
        if album:
            albums_out.append(album)

    if INCLUDE_SINGLES:
        singles_tracks = []
        for single_meta in get_all_releases(yt, artist, "singles"):
            single = collect_tracks(
                yt, artist_name, single_meta, "Singles", seen_songs, seen_video_ids
            )
            if single:
                singles_tracks.extend(single["tracks"])

        if singles_tracks:
            albums_out.append(
                {
                    "title": "Singles",
                    "thumbnail": singles_tracks[0].get("thumbnail"),
                    "tracks": singles_tracks,
                }
            )

    return {
        "artist": artist_name,
        "mode": "artist",
        "sourceTitle": artist_name,
        "channelId": channel_id,
        "thumbnail": artist_thumbnail,
        "albums": albums_out,
    }
