"""URL parsing and normalization."""

from __future__ import annotations

import re
import urllib.error
import urllib.request

from ytmusicapi import YTMusic

HANDLE_RE = re.compile(
    r"(?:music\.)?youtube\.com/@([A-Za-z0-9._-]+)",
    re.IGNORECASE,
)
CHANNEL_ID_RE = re.compile(r'"externalId"\s*:\s*"(UC[\w-]+)"')
HANDLE_SUFFIX_RE = re.compile(
    r"(?:official|vevo|music|band|tv|channel)$",
    re.IGNORECASE,
)
CAMEL_SPLIT_RE = re.compile(r"(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])")


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


def _resolve_handle_via_youtube(handle: str) -> str | None:
    """Resolve @handle to a UC... channel ID via the public YouTube page."""
    url = f"https://www.youtube.com/@{handle}"
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "Mozilla/5.0"},
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            html = response.read().decode("utf-8", "replace")
    except (urllib.error.URLError, TimeoutError, ValueError):
        return None

    match = CHANNEL_ID_RE.search(html)
    if match:
        return match.group(1)

    # Fallbacks seen on some channel pages.
    for pattern in (
        r'"channelId"\s*:\s*"(UC[\w-]+)"',
        r"https://www\.youtube\.com/channel/(UC[\w-]+)",
    ):
        match = re.search(pattern, html)
        if match:
            return match.group(1)
    return None


def _handle_search_queries(handle: str) -> list[str]:
    """Build search query variants from a noisy @handle."""
    queries: list[str] = []
    seen: set[str] = set()

    def add(value: str) -> None:
        value = value.strip()
        if value and value.casefold() not in seen:
            seen.add(value.casefold())
            queries.append(value)

    add(handle)
    add(f"@{handle}")

    stripped = HANDLE_SUFFIX_RE.sub("", handle).rstrip("._-")
    add(stripped)
    add(f"@{stripped}")

    spaced = CAMEL_SPLIT_RE.sub(" ", stripped)
    spaced = spaced.replace("_", " ").replace(".", " ").replace("-", " ")
    spaced = re.sub(r"\s+", " ", spaced).strip()
    add(spaced)

    return queries


def _match_artist_search(handle: str, results: list[dict]) -> str | None:
    compact = re.sub(r"[^a-z0-9]", "", handle.casefold())
    compact = HANDLE_SUFFIX_RE.sub("", compact)
    spaced = handle.replace("_", " ").replace(".", " ").casefold()
    spaced = HANDLE_SUFFIX_RE.sub("", spaced).strip()

    for result in results:
        name = (result.get("artist") or "").casefold()
        name_compact = re.sub(r"[^a-z0-9]", "", name)
        browse_id = result.get("browseId")
        if not browse_id:
            continue
        if name == spaced or name_compact == compact:
            return browse_id
        # Allow handle like SmashIntoPiecesofficial vs artist "Smash Into Pieces"
        if compact and name_compact and (
            compact.startswith(name_compact) or name_compact.startswith(compact)
        ):
            return browse_id

    browse_id = results[0].get("browseId") if results else None
    return browse_id or None


def resolve_artist_channel_id(yt: YTMusic, artist_ref: str) -> str:
    """Resolve a channel ID or @handle to a YouTube Music artist browseId."""
    if artist_ref.startswith("UC"):
        return artist_ref

    handle = artist_ref.lstrip("@").strip()
    if not handle:
        raise ValueError(f"Invalid artist handle: {artist_ref}")

    channel_id = _resolve_handle_via_youtube(handle)
    if channel_id:
        return channel_id

    for query in _handle_search_queries(handle):
        results = yt.search(query, filter="artists", limit=10)
        browse_id = _match_artist_search(handle, results)
        if browse_id:
            return browse_id

    raise ValueError(f"Could not resolve artist handle @{handle}")


def strip_topic_suffix(name: str) -> str:
    return re.sub(r"\s*-\s*Topic$", "", name, flags=re.IGNORECASE).strip()


def normalize_playlist_title(title: str) -> str:
    title = re.sub(r"^(album|playlist)\s*-\s*", "", title.strip(), flags=re.IGNORECASE)
    return title.strip() or "Playlist"
