"""Title filtering and normalization."""

from __future__ import annotations

import re

UNWANTED_ALBUM_RE = re.compile(
    r"(?i)"
    r"(\b(live|remix|remixes|acoustic|unplugged|karaoke|instrumental|"
    r"visualizer|visualiser|visualisers|performance|session|tribute|cover|"
    r"demos?|b-?sides?|commentary|interview|reimagined|alternate|"
    r"symphonic|orchestral|piano version|piano versions|"
    r"track by track|tour setlist|setlist|behind the scenes|"
    r"anthology|companion|collection|"
    r"from the vault|vault track|"
    r"re-?record(?:ed|ing)?|"
    r"lyric video|official video)\b"
    r"|\(\s*(live|remix|acoustic|version|visualizer|visualiser|"
    r"lyric video|piano version|demo|session|performance)\s*\)"
    r"|\[\s*(live|remix|acoustic|version|visualizer|visualiser|"
    r"lyric video|piano version|demo|session|performance)\s*\]"
    r"|\(\s*[^)]*\bversion\b[^)]*\)"
    r"|\[\s*[^\]]*\bversion\b[^\]]*\])"
)

# Soft edition markers: keep these when they are the only available release.
EDITION_SUFFIX_RE = re.compile(
    r"(?i)\s*[\(\[]\s*"
    r"(?:super\s+)?(?:deluxe|expanded|anniversary|bonus|special|limited)"
    r"(?:\s+(?:edition|version|release))?"
    r"\s*[\)\]]\s*$"
)
EDITION_WORD_RE = re.compile(
    r"(?i)\b(?:deluxe|expanded)\s+(?:edition|version)\b|\b(?:super\s+)?deluxe\b"
)

# Parenthetical / bracketed suffixes that are not part of the song name.
UNWANTED_TITLE_PARTS = re.compile(
    r"(?i)\s*"
    r"(\([^)]*(?:feat\.?|ft\.?|featuring|with\.?|w/|vs\.?|versus|"
    r"live|remix|remaster(?:ed)?|"
    r"acoustic|version|visualizer|visualiser|lyric video|official video|"
    r"official audio|piano version|demo|session|performance|"
    r"radio edit|extended|deluxe|bonus track|instrumental|"
    r"pop mix|\bmix\b|soundtrack|from the vault|motion picture|"
    r"from \"[^\"]+\"|from '[^']+'|"
    r"clean|explicit)[^)]*\)"
    r"|\[[^\]]*(?:feat\.?|ft\.?|featuring|with\.?|w/|vs\.?|versus|"
    r"live|remix|remaster(?:ed)?|"
    r"acoustic|version|visualizer|visualiser|lyric video|official video|"
    r"official audio|piano version|demo|session|performance|"
    r"radio edit|extended|deluxe|bonus track|instrumental|"
    r"pop mix|\bmix\b|soundtrack|from the vault|motion picture|"
    r"from \"[^\"]+\"|from '[^']+'|"
    r"clean|explicit)[^\]]*\])"
)

# Inline guest/other-artist credits: "feat.", "ft.", "with.", "w/", "vs.", etc.
COLLAB_CREDIT_RE = re.compile(
    r"(?i)\s*"
    r"(?:"
    r"[\(\[]\s*(?:feat\.?|ft\.?|featuring|with\.?|w/|vs\.?|versus)\b[^)\]]*[\)\]]"
    r"|"
    r"(?:feat\.?|ft\.?|featuring|with\.|w/|vs\.|versus)\s+.+$"
    r")"
)

ARTIST_PREFIX_RE = re.compile(r"^[^-]+-\s+")
YOUTUBE_ID_SUFFIX_RE = re.compile(r"\s*\[[^\]]+\]$")


def clean_song_title(title: str, artist_name: str) -> str:
    name = title.strip()
    name = YOUTUBE_ID_SUFFIX_RE.sub("", name)

    previous = None
    while previous != name:
        previous = name
        name = COLLAB_CREDIT_RE.sub("", name).strip()
        name = UNWANTED_TITLE_PARTS.sub("", name).strip()

    name = ARTIST_PREFIX_RE.sub("", name)
    name = re.sub(r"\s+", " ", name).strip(" -")
    return name or title.strip()


def normalize_for_dedup(title: str) -> str:
    value = title.lower()
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def is_unwanted_album(title: str) -> bool:
    return bool(UNWANTED_ALBUM_RE.search(title))


def is_alternate_edition(title: str) -> bool:
    return bool(EDITION_SUFFIX_RE.search(title) or EDITION_WORD_RE.search(title))


def album_base_title(title: str) -> str:
    base = EDITION_SUFFIX_RE.sub("", title).strip(" -")
    base = EDITION_WORD_RE.sub("", base)
    return normalize_for_dedup(base)


def prefer_standard_editions(releases: list[dict]) -> list[dict]:
    """Prefer non-deluxe releases when both exist; keep deluxe if it's the only one."""
    by_base: dict[str, list[dict]] = {}
    for release in releases:
        title = release.get("title") or ""
        base = album_base_title(title) or normalize_for_dedup(title)
        by_base.setdefault(base, []).append(release)

    preferred: list[dict] = []
    for group in by_base.values():
        standards = [r for r in group if not is_alternate_edition(r.get("title") or "")]
        preferred.extend(standards or group)
    return preferred
