"""URL parsing and normalization."""

from __future__ import annotations

import re


def parse_artist_id(url: str) -> str:
    patterns = [
        r"music\.youtube\.com/channel/(UC[\w-]+)",
        r"music\.youtube\.com/channel/(UC[\w-]+)/",
        r"youtube\.com/channel/(UC[\w-]+)",
    ]
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    raise ValueError(f"Could not parse artist channel ID from URL: {url}")


def detect_url_type(url: str) -> tuple[str, str]:
    playlist_match = re.search(r"[?&]list=([A-Za-z0-9_-]+)", url)
    video_match = re.search(r"(?:[?&]v=|youtu\.be/)([A-Za-z0-9_-]{11})", url)

    if re.search(r"/channel/(UC[\w-]+)", url):
        return "artist", parse_artist_id(url)

    if re.search(r"/playlist\b", url) or (playlist_match and not video_match):
        return "playlist", playlist_match.group(1)

    if playlist_match and video_match:
        return "playlist", playlist_match.group(1)

    if video_match:
        return "video", video_match.group(1)

    raise ValueError(f"Unsupported URL: {url}")


def strip_topic_suffix(name: str) -> str:
    return re.sub(r"\s*-\s*Topic$", "", name, flags=re.IGNORECASE).strip()


def normalize_playlist_title(title: str) -> str:
    title = re.sub(r"^(album|playlist)\s*-\s*", "", title.strip(), flags=re.IGNORECASE)
    return title.strip() or "Playlist"
