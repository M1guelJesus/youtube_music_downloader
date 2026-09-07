# YouTube Music Downloader

Downloads music from YouTube Music and saves it as organized high-quality MP3s.

## Features

- Auto-detects URL type:
  - **Artist channel** (`/channel/UC...`) → all studio albums
  - **Artist handle** (`/@ArtistName`) → resolves handle, then studio albums
  - **Playlist** → entire playlist
  - **Single video** → one track
- Filters out live, remix, deluxe, Taylor's Version-style, and similar non-studio releases
- Deduplicates tracks (never downloads the same song twice)
- Cleans song filenames (strips `feat.`, `ft.`, `with.`, YouTube IDs, etc.)
- Downloads best available audio and converts to MP3
- Saves album covers (`cover.jpg`) and embeds them in MP3 metadata
- Optional singles download, dry-run, and JSON metadata dump

## Requirements

- `bash`
- `yt-dlp`
- `ffmpeg`
- `curl`
- `python3`
- Python package: [`ytmusicapi`](https://github.com/sigma67/ytmusicapi)

```bash
pip install ytmusicapi
```

Optional but recommended: a cookies file for yt-dlp (`cookies.txt` or `cookies-youtube-com.txt` in this directory). Cookies are auto-detected if present.

## Usage

```bash
./downloader_v2.sh [OPTIONS] URL
```

### Examples

```bash
# Artist by channel ID
./downloader_v2.sh "https://music.youtube.com/channel/UCqECaJ8Gagnn7YCbPEzWH6g"

# Artist by @handle
./downloader_v2.sh "https://music.youtube.com/@WrittenByWolves"

# Include singles too
./downloader_v2.sh -s "https://music.youtube.com/@WrittenByWolves"

# Playlist
./downloader_v2.sh "https://music.youtube.com/playlist?list=OLAK5uy_..."

# Single track
./downloader_v2.sh "https://music.youtube.com/watch?v=dQw4w9WgXcQ"

# Preview without downloading
./downloader_v2.sh --dry-run "https://music.youtube.com/@WrittenByWolves"

# Dump catalog metadata as JSON
./downloader_v2.sh -m "https://music.youtube.com/@WrittenByWolves" > catalog.json

# Custom output folder and cookies
./downloader_v2.sh -c cookies.txt -o ~/Music "https://music.youtube.com/@WrittenByWolves"
```

## Options

| Option | Description |
|--------|-------------|
| `-o, --output-dir DIR` | Output directory (default: `./downloads`) |
| `-c, --cookies FILE` | Cookies file for yt-dlp |
| `-a, --archive FILE` | Download archive file (default: `.download_archive.txt`) |
| `-q, --quality N` | MP3 VBR quality `0`–`9` (lower is better, default: `0`) |
| `-s, --include-singles` | Also download singles under `{artist}/Singles/` |
| `-n, --dry-run` | List albums/tracks without downloading |
| `-m, --metadata-only` | Dump catalog metadata as JSON and exit |
| `-h, --help` | Show help |

## Output layout

```
downloads/
└── Artist Name/
    ├── Album Name/
    │   ├── cover.jpg
    │   ├── Song One.mp3
    │   └── Song Two.mp3
    └── Singles/          # only with -s, or for single-video downloads
        ├── cover.jpg
        └── Some Single.mp3
```

Each MP3 includes:

- ID3 tags: `title`, `artist`, `album`
- Embedded album cover

## Project structure

```
downloader_v2.sh          # Entry point
lib/                      # Bash modules (args, download, orchestration)
ytm_downloader/           # Python package (catalog, filtering, thumbnails)
```

## Notes

- Studio-album mode skips live/remix/acoustic/deluxe/version-style releases by default.
- Playlist and single-video modes download the requested content as-is (filename cleaning still applies).
- Already-downloaded video IDs are tracked in `.download_archive.txt` so re-runs skip them.
- Cookies files matching `cookies*` are gitignored.
