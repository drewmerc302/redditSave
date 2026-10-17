import Foundation
import Observation
import Photos
import RedditMedia

/// Drives one save: link -> MP4 with sound -> Photos. Used by the app and the Share Extension.
@MainActor @Observable
final class SaveModel {
    enum State: Equatable {
        case idle
        case working(String)
        case saved(hasAudio: Bool)
        case failed(String)
    }

    private(set) var state: State = .idle

    var isWorking: Bool {
        if case .working = state { true } else { false }
    }

    func save(text: String) async {
        guard let link = PostLink.find(in: text) else {
            state = .failed(RedditMediaError.notARedditLink.localizedDescription)
            return
        }
        await save(link)
    }

    func save(_ link: PostLink) async {
        state = .working("Finding video…")
        do {
            let result = try await RedditVideoFetcher().fetch(link) { stage in
                Task { @MainActor [weak self] in
                    guard let self, self.isWorking else { return }
                    let step = switch stage {
                    case .findingVideo: "Finding video…"
                    case .downloading: "Downloading…"
                    case .combining: "Adding sound…"
                    }
                    self.state = .working(step)
                }
            }
            defer { try? FileManager.default.removeItem(at: result.file.deletingLastPathComponent()) }
            state = .working("Saving to Photos…")
            try await PhotoSaver.saveVideo(at: result.file)
            state = .saved(hasAudio: result.hasAudio)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

enum PhotoSaver {
    struct NotAllowed: LocalizedError {
        var errorDescription: String? {
            "Photos access is off. Turn on Settings > Apps > Reddit Save > Photos > Add Photos Only."
        }
    }

    /// Add-only access: the app can put videos in the library but never read it.
    static func saveVideo(at url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw NotAllowed() }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }
}
