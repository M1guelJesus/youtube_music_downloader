"""Single video catalog fetching."""

from __future__ import annotations

import json
import subprocess

from ytmusicapi import YTMusic

from ytm_downloader.tracks import build_track_entry
from ytm_downloader.url import strip_topic_suffix
from ytm_downloader.ytdlp import ytdlp_cmd


def fetch_video_catalog(
    yt: YTMusic,
    video_id: str,
    url: str,
    seen_songs: set[str],
    seen_video_ids: set[str],
) -> dict:
    artist_name = "Unknown Artist"
    raw_title = "Unknown Track"

    try:
        song = yt.get_song(video_id)
        video_details = song.get("videoDetails") or {}
        raw_title = video_details.get("title") or raw_title
        artist_name = strip_topic_suffix(video_details.get("author") or artist_name)
    except Exception:
        cmd = ytdlp_cmd("-j", "--no-playlist", url)
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        if result.returncode != 0:
            raise ValueError(result.stderr.strip() or "yt-dlp failed to read video")
        entry = json.loads(result.stdout)
        raw_title = entry.get("title") or raw_title
        artist_name = strip_topic_suffix(
            entry.get("artist") or entry.get("uploader") or artist_name
        )

    track = build_track_entry(
        video_id, raw_title, artist_name, seen_songs, seen_video_ids
    )
    if not track:
        raise ValueError(f"Could not process video: {video_id}")

    return {
        "artist": artist_name,
        "mode": "video",
        "sourceTitle": track["cleanTitle"],
        "albums": [{"title": "Singles", "tracks": [track]}],
    }
