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
    r"expanded edition|deluxe edition|deluxe version|"
    r"anthology|companion|collection|"
    r"from the vault|vault track|"
    r"re-?record(?:ed|ing)?|reissue|"
    r"lyric video|official video)\b"
    r"|\(\s*(live|remix|acoustic|version|visualizer|visualiser|"
    r"lyric video|piano version|demo|session|performance)\s*\)"
    r"|\[\s*(live|remix|acoustic|version|visualizer|visualiser|"
    r"lyric video|piano version|demo|session|performance)\s*\]"
    r"|\(\s*[^)]*\bversion\b[^)]*\)"
    r"|\[\s*[^\]]*\bversion\b[^\]]*\])"
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
