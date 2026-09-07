"""Thumbnail URL helpers."""

from __future__ import annotations


def best_thumbnail(thumbnails: list[dict] | None) -> str | None:
    if not thumbnails:
        return None

    best = None
    best_area = -1
    for thumb in thumbnails:
        url = thumb.get("url")
        if not url:
            continue
        width = int(thumb.get("width") or 0)
        height = int(thumb.get("height") or 0)
        area = width * height
        if area >= best_area:
            best_area = area
            best = url

    return best


def video_thumbnail(video_id: str) -> str:
    return f"https://i.ytimg.com/vi/{video_id}/maxresdefault.jpg"


def resolve_track_thumbnail(
    video_id: str,
    track_thumbnails: list[dict] | None = None,
    album_thumbnail: str | None = None,
) -> str | None:
    return (
        best_thumbnail(track_thumbnails)
        or album_thumbnail
        or (video_thumbnail(video_id) if video_id else None)
    )
