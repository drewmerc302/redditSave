import Foundation

public enum RedditMediaError: LocalizedError, Equatable {
    case notARedditLink
    case missingSubreddit
    case notAVideo
    case badManifest
    case http(Int, String)
    case mergeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notARedditLink: "That doesn't look like a Reddit post link."
        case .missingSubreddit: "Couldn't find the post from that link. Share the full post link instead."
        case .notAVideo: "This post doesn't have a Reddit-hosted video."
        case .badManifest: "Reddit's video info couldn't be read."
        case let .http(code, what): "Reddit returned error \(code) while loading the \(what)."
        case let .mergeFailed(why): "Couldn't combine video and sound (\(why))."
        }
    }
}

public struct DownloadedVideo: Sendable {
    /// An MP4 in a temporary folder. The caller saves it and then deletes the folder.
    public var file: URL
    public var hasAudio: Bool
}

public enum FetchStage: Sendable {
    case findingVideo, downloading, combining
}

/// Turns a shared Reddit link into a local MP4 with sound. No Reddit login needed:
/// it reads the public embed page, then the public v.redd.it files.
public struct RedditVideoFetcher: Sendable {
    // Reddit answers 403 to non-browser user agents on the embed page.
    static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetch(_ link: PostLink, onStage: @Sendable (FetchStage) -> Void = { _ in }) async throws -> DownloadedVideo {
        onStage(.findingVideo)
        let work = FileManager.default.temporaryDirectory
            .appending(path: "RedditSave-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        do {
            return try await fetch(link, into: work, onStage: onStage)
        } catch {
            // On success the caller owns the folder; on failure nobody does.
            try? FileManager.default.removeItem(at: work)
            throw error
        }
    }

    private func fetch(_ link: PostLink, into work: URL, onStage: @Sendable (FetchStage) -> Void) async throws -> DownloadedVideo {
        let videoID: String
        switch try await resolve(link) {
        case let .video(id):
            videoID = id
        case let resolved:
            guard let embedURL = resolved.embedURL else { throw RedditMediaError.missingSubreddit }
            let html = try await text(from: embedURL, what: "post")
            let page = EmbedPage(html: html)
            if let packaged = page.bestPackagedMP4 {
                onStage(.downloading)
                let file = try await download(packaged, to: work.appending(path: "video.mp4"), what: "video")
                return DownloadedVideo(file: file, hasAudio: true)
            }
            guard let id = page.videoID else { throw RedditMediaError.notAVideo }
            videoID = id
        }

        let base = URL(string: "https://v.redd.it/\(videoID)/")!
        let (mpdData, _) = try await get(base.appending(path: "DASHPlaylist.mpd"), what: "video info")
        let manifest = try DASHManifest(data: mpdData)
        guard let bestVideo = manifest.bestVideo else { throw RedditMediaError.notAVideo }

        onStage(.downloading)
        async let videoFile = download(base.appending(path: bestVideo.file), to: work.appending(path: "v.mp4"), what: "video")
        async let audioFile: URL? = {
            guard let a = manifest.bestAudio else { return nil }
            return try await download(base.appending(path: a.file), to: work.appending(path: "a.mp4"), what: "sound")
        }()
        let (v, a) = try await (videoFile, audioFile)

        onStage(.combining)
        let output = work.appending(path: "\(videoID).mp4")
        try await Merger.merge(video: v, audio: a, to: output)
        return DownloadedVideo(file: output, hasAudio: a != nil)
    }

    /// Follows redirects for links that don't name the subreddit yet.
    func resolve(_ link: PostLink) async throws -> PostLink {
        guard case let .needsRedirect(url) = link else { return link }
        let (_, response) = try await get(url, what: "link")
        guard let final = response.url, let resolved = PostLink(url: final) else {
            throw RedditMediaError.missingSubreddit
        }
        if case .needsRedirect = resolved { throw RedditMediaError.missingSubreddit }
        return resolved
    }

    private func request(_ url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        req.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        return req
    }

    private func get(_ url: URL, what: String) async throws -> (Data, URLResponse) {
        let (data, response) = try await session.data(for: request(url))
        try check(response, what: what)
        return (data, response)
    }

    private func text(from url: URL, what: String) async throws -> String {
        let (data, _) = try await get(url, what: what)
        return String(decoding: data, as: UTF8.self)
    }

    private func download(_ url: URL, to destination: URL, what: String) async throws -> URL {
        let (temp, response) = try await session.download(for: request(url))
        try check(response, what: what)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temp, to: destination)
        return destination
    }

    private func check(_ response: URLResponse, what: String) throws {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RedditMediaError.http(http.statusCode, what)
        }
    }
}
