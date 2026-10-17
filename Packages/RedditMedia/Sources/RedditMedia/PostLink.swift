import Foundation

/// What a shared link points at, as far as we can tell without the network.
public enum PostLink: Equatable, Sendable {
    /// A post we can look up through its embed page.
    case post(subreddit: String, id: String)
    /// A direct v.redd.it link: the video ID is already known.
    case video(id: String)
    /// A link that has to be followed first (redd.it/<id>, /r/<sub>/s/<code>, /comments/<id>).
    case needsRedirect(URL)

    /// Pulls the first Reddit link out of shared text or a URL string.
    /// Share sheets hand over either a URL or text like "Check this out https://...".
    public static func find(in text: String) -> PostLink? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        for match in detector?.matches(in: text, range: range) ?? [] {
            if let url = match.url, let link = PostLink(url: url) { return link }
        }
        return nil
    }

    public init?(url: URL) {
        guard let host = url.host()?.lowercased() else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }

        if host == "v.redd.it" {
            guard let id = parts.first, !id.isEmpty else { return nil }
            self = .video(id: id)
            return
        }
        if host == "redd.it" {
            guard !parts.isEmpty else { return nil }
            self = .needsRedirect(url)
            return
        }
        guard host == "reddit.com" || host.hasSuffix(".reddit.com") else { return nil }

        // /r/<sub>/comments/<id>/<slug?>
        if parts.count >= 4, parts[0].lowercased() == "r", parts[2] == "comments" {
            self = .post(subreddit: parts[1], id: parts[3])
            return
        }
        // /r/<sub>/s/<code> share links, /comments/<id>, /video/<id>
        if (parts.count >= 4 && parts[0].lowercased() == "r" && parts[2] == "s")
            || (parts.count >= 2 && (parts[0] == "comments" || parts[0] == "video")) {
            self = .needsRedirect(url)
            return
        }
        return nil
    }

    /// The public embed page. It loads without a Reddit login, unlike the post itself.
    public var embedURL: URL? {
        guard case let .post(sub, id) = self else { return nil }
        return URL(string: "https://embed.reddit.com/r/\(sub)/comments/\(id)/")
    }
}
