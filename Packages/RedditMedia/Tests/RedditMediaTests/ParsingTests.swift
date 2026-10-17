import Foundation
import Testing
@testable import RedditMedia

private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

@Suite struct PostLinkTests {
    @Test func fullPostLink() {
        let link = PostLink.find(in: "https://www.reddit.com/r/HeavySeas/comments/1x83yc8/another_brilliant_drill_with_rescue_boat/")
        #expect(link == .post(subreddit: "HeavySeas", id: "1x83yc8"))
        #expect(link?.embedURL?.absoluteString == "https://embed.reddit.com/r/HeavySeas/comments/1x83yc8/")
    }

    @Test func linkInsideSharedTextWithTracking() {
        let link = PostLink.find(in: "Look at this https://old.reddit.com/r/Guitar/comments/1x8fvc9/hotel_california_solo/?utm_source=share&utm_medium=ios_app")
        #expect(link == .post(subreddit: "Guitar", id: "1x8fvc9"))
    }

    @Test func directVideoLink() {
        #expect(PostLink.find(in: "https://v.redd.it/di3o3i5d5uvh1") == .video(id: "di3o3i5d5uvh1"))
    }

    @Test func linksThatNeedARedirect() {
        for s in ["https://redd.it/1x83yc8",
                  "https://www.reddit.com/r/HeavySeas/s/AbC123",
                  "https://www.reddit.com/comments/1x83yc8"] {
            guard case .needsRedirect = PostLink.find(in: s) else {
                Issue.record("expected redirect for \(s)"); continue
            }
        }
    }

    @Test func nonRedditLinks() {
        #expect(PostLink.find(in: "https://youtube.com/watch?v=abc") == nil)
        #expect(PostLink.find(in: "no link here") == nil)
        #expect(PostLink.find(in: "https://www.reddit.com/r/Guitar/") == nil)
    }
}

@Suite struct EmbedPageTests {
    @Test func packagedMP4sPicksTallest() throws {
        let page = EmbedPage(html: String(decoding: try fixture("embed-packaged.html"), as: UTF8.self))
        #expect(page.videoID == "x42hktj5ruvh1")
        #expect(page.packagedMP4s.keys.sorted() == [392, 480, 640, 854, 1280])
        let best = try #require(page.bestPackagedMP4).absoluteString
        #expect(best.contains("m2-res_1280p.mp4"))
        // HTML entities must be decoded or the signed URL is rejected.
        #expect(!best.contains("&amp;") && !best.contains("&quot;"))
        #expect(best.contains("&s="))
    }

    @Test func dashOnlyPage() throws {
        let page = EmbedPage(html: String(decoding: try fixture("embed-dash-only.html"), as: UTF8.self))
        #expect(page.videoID == "di3o3i5d5uvh1")
        #expect(page.packagedMP4s.isEmpty)
    }
}

@Suite struct DASHManifestTests {
    @Test func picksBestVideoAndAudio() throws {
        let m = try DASHManifest(data: try fixture("cranes.mpd"))
        #expect(m.video.count == 4)
        #expect(m.audio.count == 2)
        #expect(m.bestVideo?.file == "CMAF_480.mp4")
        #expect(m.bestVideo?.height == 476)
        // Both audio files report the same bandwidth; the file name decides.
        #expect(m.bestAudio?.file == "CMAF_AUDIO_128.mp4")
    }

    @Test func videoOnlyManifest() throws {
        let xml = """
        <MPD><Period><AdaptationSet contentType="video">
        <Representation bandwidth="100" height="480" mimeType="video/mp4"><BaseURL>DASH_480.mp4</BaseURL></Representation>
        </AdaptationSet></Period></MPD>
        """
        let m = try DASHManifest(data: Data(xml.utf8))
        #expect(m.bestVideo?.file == "DASH_480.mp4")
        #expect(m.bestAudio == nil)
    }
}
