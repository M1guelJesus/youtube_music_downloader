"""URL parsing and normalization."""

from __future__ import annotations

import re

from ytmusicapi import YTMusic

HANDLE_RE = re.compile(
    r"(?:music\.)?youtube\.com/@([A-Za-z0-9._-]+)",
    re.IGNORECASE,
)


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


def parse_artist_handle(url: str) -> str:
    match = HANDLE_RE.search(url)
    if not match:
        raise ValueError(f"Could not parse artist handle from URL: {url}")
    return match.group(1)


def detect_url_type(url: str) -> tuple[str, str]:
    playlist_match = re.search(r"[?&]list=([A-Za-z0-9_-]+)", url)
    video_match = re.search(r"(?:[?&]v=|youtu\.be/)([A-Za-z0-9_-]{11})", url)

    if re.search(r"/channel/(UC[\w-]+)", url):
        return "artist", parse_artist_id(url)

    if HANDLE_RE.search(url):
        return "artist", f"@{parse_artist_handle(url)}"

    if re.search(r"/playlist\b", url) or (playlist_match and not video_match):
        return "playlist", playlist_match.group(1)

    if playlist_match and video_match:
        return "playlist", playlist_match.group(1)

    if video_match:
        return "video", video_match.group(1)

    raise ValueError(f"Unsupported URL: {url}")


def resolve_artist_channel_id(yt: YTMusic, artist_ref: str) -> str:
    """Resolve a channel ID or @handle to a YouTube Music artist browseId."""
    if artist_ref.startswith("UC"):
        return artist_ref

    handle = artist_ref.lstrip("@").strip()
    if not handle:
        raise ValueError(f"Invalid artist handle: {artist_ref}")

    query = handle
    results = yt.search(query, filter="artists", limit=10)
    if not results:
        results = yt.search(f"@{handle}", filter="artists", limit=10)

    if not results:
        raise ValueError(f"Could not resolve artist handle @{handle}")

    compact = re.sub(r"[^a-z0-9]", "", handle.casefold())
    spaced = handle.replace("_", " ").replace(".", " ").casefold()

    for result in results:
        name = (result.get("artist") or "").casefold()
        name_compact = re.sub(r"[^a-z0-9]", "", name)
        browse_id = result.get("browseId")
        if not browse_id:
            continue
        if name == spaced or name_compact == compact:
            return browse_id

    browse_id = results[0].get("browseId")
    if not browse_id:
        raise ValueError(f"Could not resolve artist handle @{handle}")
    return browse_id


def strip_topic_suffix(name: str) -> str:
    return re.sub(r"\s*-\s*Topic$", "", name, flags=re.IGNORECASE).strip()


def normalize_playlist_title(title: str) -> str:
    title = re.sub(r"^(album|playlist)\s*-\s*", "", title.strip(), flags=re.IGNORECASE)
    return title.strip() or "Playlist"
