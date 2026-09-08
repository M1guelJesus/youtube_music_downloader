"""Track building and album collection helpers."""

from __future__ import annotations

import sys

from ytmusicapi import YTMusic

from ytm_downloader.filters import (
    clean_song_title,
    is_unwanted_album,
    normalize_for_dedup,
    prefer_standard_editions,
)
from ytm_downloader.thumbnails import best_thumbnail, resolve_track_thumbnail


def build_track_entry(
    video_id: str,
    raw_title: str,
    artist_name: str,
    seen_songs: set[str],
    seen_video_ids: set[str],
    thumbnail: str | None = None,
    track_thumbnails: list[dict] | None = None,
    album_thumbnail: str | None = None,
) -> dict | None:
    if not video_id or video_id in seen_video_ids:
        return None

    clean_title = clean_song_title(raw_title, artist_name)
    dedup_key = normalize_for_dedup(clean_title)
    if dedup_key in seen_songs:
        return None

    seen_songs.add(dedup_key)
    seen_video_ids.add(video_id)

    resolved_thumbnail = thumbnail or resolve_track_thumbnail(
        video_id, track_thumbnails, album_thumbnail
    )

    return {
        "videoId": video_id,
        "rawTitle": raw_title,
        "cleanTitle": clean_title,
        "dedupKey": dedup_key,
        "thumbnail": resolved_thumbnail,
    }


def get_all_releases(yt: YTMusic, artist: dict, section_key: str) -> list[dict]:
    section = artist.get(section_key) or {}
    releases = list(section.get("results") or [])

    params = section.get("params")
    browse_id = section.get("browseId") or artist.get("channelId")
    if params and browse_id:
        releases = yt.get_artist_albums(browse_id, params, limit=None)

    deduped = []
    seen_ids = set()
    for release in releases:
        release_browse_id = release.get("browseId")
        if not release_browse_id or release_browse_id in seen_ids:
            continue
        seen_ids.add(release_browse_id)
        deduped.append(release)
    return prefer_standard_editions(deduped)


def collect_tracks(
    yt: YTMusic,
    artist_name: str,
    release_meta: dict,
    album_folder: str,
    seen_songs: set[str],
    seen_video_ids: set[str],
) -> dict | None:
    release_title = release_meta.get("title") or "Unknown Album"
    if is_unwanted_album(release_title):
        return None

    browse_id = release_meta.get("browseId")
    if not browse_id:
        return None

    try:
        release = yt.get_album(browse_id)
    except Exception as exc:
        print(f"Skipping release '{release_title}': {exc}", file=sys.stderr)
        return None

    album_thumbnail = best_thumbnail(release.get("thumbnails")) or best_thumbnail(
        release_meta.get("thumbnails")
    )

    tracks_out = []
    for track in release.get("tracks") or []:
        video_id = track.get("videoId")
        raw_title = track.get("title") or "Unknown Track"
        if not video_id or video_id in seen_video_ids:
            continue

        if is_unwanted_album(raw_title):
            continue

        clean_title = clean_song_title(raw_title, artist_name)
        if is_unwanted_album(clean_title):
            continue

        dedup_key = normalize_for_dedup(clean_title)
        if dedup_key in seen_songs:
            continue

        seen_songs.add(dedup_key)
        seen_video_ids.add(video_id)
        tracks_out.append(
            {
                "videoId": video_id,
                "rawTitle": raw_title,
                "cleanTitle": clean_title,
                "dedupKey": dedup_key,
                "thumbnail": resolve_track_thumbnail(
                    video_id, track.get("thumbnails"), album_thumbnail
                ),
            }
        )

    if not tracks_out:
        return None

    return {
        "title": album_folder or release.get("title") or release_title,
        "thumbnail": album_thumbnail,
        "tracks": tracks_out,
    }
