"""yt-dlp command helpers."""

from __future__ import annotations

import os


def ytdlp_cmd(*args: str) -> list[str]:
    cmd = ["yt-dlp", "--no-update"]

    js_runtime = os.environ.get("YTDLP_JS_RUNTIME", "")
    if js_runtime:
        cmd.extend(["--js-runtimes", js_runtime, "--remote-components", "ejs:github"])

    cookies_browser = os.environ.get("COOKIES_FROM_BROWSER", "")
    cookies = os.environ.get("COOKIES_FILE", "")
    if cookies_browser:
        cmd.extend(["--cookies-from-browser", cookies_browser])
    elif cookies:
        cmd.extend(["--cookies", cookies])

    cmd.extend(args)
    return cmd
