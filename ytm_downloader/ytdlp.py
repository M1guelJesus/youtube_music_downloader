"""yt-dlp command helpers."""

from __future__ import annotations

import os


def ytdlp_cmd(*args: str) -> list[str]:
    cmd = ["yt-dlp", "--no-update", *args]
    cookies = os.environ.get("COOKIES_FILE", "")
    if cookies:
        cmd[1:1] = ["--cookies", cookies]
    return cmd
