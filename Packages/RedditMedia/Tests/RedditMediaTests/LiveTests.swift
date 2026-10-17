import AVFoundation
import Foundation
import Testing
@testable import RedditMedia

/// Hits real Reddit. Off by default: run with `REDDIT_LIVE=1 swift test`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["REDDIT_LIVE"] == "1"))
struct LiveTests {
    @Test(arguments: [
        // No packaged MP4: exercises download + merge.
        "https://www.reddit.com/r/HeavySeas/comments/1x83yc8/another_brilliant_drill_with_rescue_boat/",
        // Has a packaged MP4 with sound: exercises the shortcut path.
        "https://www.reddit.com/r/Damnthatsinteresting/comments/1x7k51w/storm_in_lorenzo_nebraska/",
        // Direct video link.
        "https://v.redd.it/di3o3i5d5uvh1",
    ])
    func downloadsWithSound(_ link: String) async throws {
        let post = try #require(PostLink.find(in: link))
        let result = try await RedditVideoFetcher().fetch(post)
        defer { try? FileManager.default.removeItem(at: result.file.deletingLastPathComponent()) }

        let asset = AVURLAsset(url: result.file)
        #expect(try await !asset.loadTracks(withMediaType: .video).isEmpty)
        #expect(try await !asset.loadTracks(withMediaType: .audio).isEmpty)
        #expect(result.hasAudio)
        #expect(try await asset.load(.duration).seconds > 1)
    }

    /// redd.it redirects to /comments/<id> with no subreddit. Reddit sometimes redirects on to the
    /// full post and sometimes answers with a JavaScript bot challenge (seemingly cookie-dependent).
    /// Either outcome is fine; anything else is not.
    @Test func bareShortLinkWorksOrFailsClearly() async throws {
        let post = try #require(PostLink.find(in: "https://redd.it/1x83yc8"))
        do {
            let result = try await RedditVideoFetcher().fetch(post)
            try? FileManager.default.removeItem(at: result.file.deletingLastPathComponent())
            #expect(result.hasAudio)
        } catch let error as RedditMediaError {
            #expect(error == .missingSubreddit)
        }
    }
}
