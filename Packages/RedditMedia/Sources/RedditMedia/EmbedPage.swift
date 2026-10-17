import Foundation

/// What we can read off a post's embed page.
public struct EmbedPage: Equatable, Sendable {
    /// The v.redd.it video ID, if the post is a Reddit-hosted video.
    public var videoID: String?
    /// Ready-made MP4s with audio already muxed in, keyed by height. Only some posts have them.
    public var packagedMP4s: [Int: URL]

    public var bestPackagedMP4: URL? {
        packagedMP4s.max { $0.key < $1.key }?.value
    }

    public init(html: String) {
        // The media data sits in an HTML-escaped JSON attribute.
        let text = html
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "\\u0026", with: "&")

        let id = text.firstMatch(of: /v\.redd\.it\/([a-z0-9]+)/).map { String($0.1) }
        videoID = id

        var mp4s: [Int: URL] = [:]
        for m in text.matches(of: /https:\/\/packaged-media\.redd\.it\/([a-z0-9]+)\/pb\/m2-res_(\d+)p\.mp4[^"\s<]*/) {
            // Ignore packaged files for other videos (recommended posts and the like).
            guard id == nil || String(m.1) == id,
                  let height = Int(m.2),
                  let url = URL(string: String(m.0)) else { continue }
            mp4s[height] = url
        }
        packagedMP4s = mp4s
    }
}
