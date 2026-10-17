# Reddit Save

An iOS share-sheet action that saves Reddit videos to Photos **with sound**.

Reddit hosts video and audio as separate files, so many apps (Hydra's built-in download, for one) save silent clips. Reddit Save fetches both and combines them on the phone, without re-encoding.

## Use it

1. In Hydra, Safari, the Reddit app, or anywhere else that shares a Reddit link, tap **Share** on a video post.
2. Tap **Save Reddit Video** in the action list. If it isn't there, scroll to the bottom, tap **Edit Actions**, and add it.
3. The first time, allow it to add to Photos. It shows progress, says "Saved to Photos with sound", and closes.

The app itself only holds instructions and a paste-a-link box. You never need to open it.

## How it works

No Reddit account or API key is needed.

1. **Find the video.** The post's public embed page (`embed.reddit.com/r/<sub>/comments/<id>/`) loads without a login and names the `v.redd.it` video ID. It needs a browser User-Agent; anything else gets a 403.
2. **Take the shortcut when there is one.** Some embed pages list pre-packaged MP4s with audio already included. If so, it downloads the tallest one.
3. **Otherwise, combine.** `v.redd.it/<id>/DASHPlaylist.mpd` is public. It downloads the best video and audio files and merges them with `AVMutableComposition` and a passthrough `AVAssetExportSession`, with the index moved to the front of the file (Photos rejects MP4s without that).
4. **Save.** It adds the file to Photos with add-only access, so it can never read your library.

Posts with no audio track (GIF-style clips) are saved silently, and the result says so.

## Limits

- Bare `redd.it/<id>` and `/comments/<id>` links don't name the subreddit, and Reddit sometimes answers them with a JavaScript bot check. They work some of the time; otherwise you get "Share the full post link instead." Normal share links from Hydra, Safari and the Reddit app include the subreddit.
- This relies on Reddit's embed page, which isn't a documented API. If saving stops working, that page is the first suspect; the live tests below will show it within seconds.
- Quality is whatever Reddit has. Some posts top out at 480p.

## Build

Requires Xcode 26, iOS 18, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

1. Set `DEVELOPMENT_TEAM` in `project.yml` to your own team ID.
2. Run `xcodegen generate` (the `.xcodeproj` is generated, not committed).
3. Open `RedditSave.xcodeproj` and run on your phone.

## Tests

The Reddit logic lives in `Packages/RedditMedia` and runs on macOS:

```sh
cd Packages/RedditMedia
swift test                    # parsers, against saved real responses
REDDIT_LIVE=1 swift test      # also downloads real posts from Reddit
```

The live tests use specific public posts; if one gets deleted, swap in another.

## Layout

| Path | What |
| --- | --- |
| `Packages/RedditMedia` | Link parsing, embed page and manifest parsing, download and merge |
| `Shared` | Save flow and status view, used by both the app and the extension |
| `RedditSave` | The app (instructions + paste a link) |
| `RedditSaveAction` | The share-sheet action |
| `Scripts/make_icon.py` | Regenerates the app icon (needs Pillow) |

## Disclaimer

Not affiliated with or endorsed by Reddit. Save only what you have the right to keep, and respect the people who posted it.

## License

MIT. See [LICENSE](LICENSE).
