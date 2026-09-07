"""Playlist catalog fetching."""

from __future__ import annotations

import json
import subprocess

from ytmusicapi import YTMusic

from ytm_downloader.tracks import build_track_entry
from ytm_downloader.thumbnails import best_thumbnail
from ytm_downloader.url import normalize_playlist_title, strip_topic_suffix
from ytm_downloader.ytdlp import ytdlp_cmd


def fetch_playlist_catalog_ytmusic(
    yt: YTMusic,
    playlist_id: str,
    seen_songs: set[str],
    seen_video_ids: set[str],
) -> dict:
    playlist = yt.get_playlist(playlist_id, limit=None)
    tracks = playlist.get("tracks") or []
    if not tracks:
        raise ValueError(f"Playlist is empty: {playlist_id}")

    artist_name = "Unknown Artist"
    for track in tracks:
        artists = track.get("artists") or []
        if artists and artists[0].get("name"):
            artist_name = artists[0]["name"]
            break

    album_title = normalize_playlist_title(playlist.get("title") or "Playlist")
    album_thumbnail = best_thumbnail(playlist.get("thumbnails"))
    tracks_out = []

    for track in tracks:
        entry = build_track_entry(
            track.get("videoId") or "",
            track.get("title") or "Unknown Track",
            artist_name,
            seen_songs,
            seen_video_ids,
            track_thumbnails=track.get("thumbnails"),
            album_thumbnail=album_thumbnail,
        )
        if entry:
            tracks_out.append(entry)

    if not tracks_out:
        raise ValueError(f"No downloadable tracks found in playlist: {playlist_id}")

    if not album_thumbnail:
        album_thumbnail = tracks_out[0].get("thumbnail")

    return {
        "artist": artist_name,
        "mode": "playlist",
        "sourceTitle": album_title,
        "thumbnail": album_thumbnail,
        "albums": [
            {
                "title": album_title,
                "thumbnail": album_thumbnail,
                "tracks": tracks_out,
            }
        ],
    }


def fetch_playlist_catalog_ytdlp(
    url: str,
    seen_songs: set[str],
    seen_video_ids: set[str],
) -> dict:
    cmd = ytdlp_cmd("--flat-playlist", "-j", url)
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise ValueError(result.stderr.strip() or "yt-dlp failed to read playlist")

    entries = []
    for line in result.stdout.splitlines():
        line = line.strip()
        if line:
            entries.append(json.loads(line))

    if not entries:
        raise ValueError(f"Playlist is empty: {url}")

    playlist_title = normalize_playlist_title(
        entries[0].get("playlist_title") or "Playlist"
    )
    artist_name = strip_topic_suffix(
        entries[0].get("playlist_uploader")
        or entries[0].get("playlist_channel")
        or entries[0].get("uploader")
        or "Unknown Artist"
    )

    tracks_out = []
    for entry in entries:
        thumbs = entry.get("thumbnails")
        track = build_track_entry(
            entry.get("id") or "",
            entry.get("title") or "Unknown Track",
            artist_name,
            seen_songs,
            seen_video_ids,
            track_thumbnails=thumbs if isinstance(thumbs, list) else None,
        )
        if track:
            tracks_out.append(track)

    if not tracks_out:
        raise ValueError(f"No downloadable tracks found in playlist: {url}")

    album_thumbnail = tracks_out[0].get("thumbnail")

    return {
        "artist": artist_name,
        "mode": "playlist",
        "sourceTitle": playlist_title,
        "thumbnail": album_thumbnail,
        "albums": [
            {
                "title": playlist_title,
                "thumbnail": album_thumbnail,
                "tracks": tracks_out,
            }
        ],
    }


def fetch_playlist_catalog(
    yt: YTMusic,
    playlist_id: str,
    url: str,
    seen_songs: set[str],
    seen_video_ids: set[str],
) -> dict:
    try:
        return fetch_playlist_catalog_ytmusic(
            yt, playlist_id, seen_songs, seen_video_ids
        )
    except Exception:
        return fetch_playlist_catalog_ytdlp(url, seen_songs, seen_video_ids)
