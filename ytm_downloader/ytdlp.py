"""yt-dlp command helpers."""

from __future__ import annotations

import os


def ytdlp_cmd(*args: str) -> list[str]:
    cmd = ["yt-dlp", "--no-update"]

    js_runtime = os.environ.get("YTDLP_JS_RUNTIME", "")
    if js_runtime:
        cmd.extend(["--js-runtimes", js_runtime, "--remote-components", "ejs:github"])

    # Browser cookies are extracted once into COOKIES_FILE when needed.
    cookies_enabled = os.environ.get("COOKIES_ENABLED", "false") == "true"
    cookies = os.environ.get("COOKIES_FILE", "")
    if cookies_enabled and cookies:
        cmd.extend(["--cookies", cookies])

    cmd.extend(args)
    return cmd
