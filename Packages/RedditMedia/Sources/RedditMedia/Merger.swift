import AVFoundation

/// Combines Reddit's separate video and audio files into one MP4 without re-encoding.
/// With no audio (GIF-style posts), it still rewrites the video so Photos accepts it.
enum Merger {
    static func merge(video videoURL: URL, audio audioURL: URL?, to output: URL) async throws {
        let video = AVURLAsset(url: videoURL)
        let comp = AVMutableComposition()

        guard let vSrc = try await video.loadTracks(withMediaType: .video).first,
              let vTrack = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw RedditMediaError.mergeFailed("no video track") }
        let vRange = try await vSrc.load(.timeRange)
        try vTrack.insertTimeRange(vRange, of: vSrc, at: .zero)
        vTrack.preferredTransform = try await vSrc.load(.preferredTransform)

        if let audioURL {
            let audio = AVURLAsset(url: audioURL)
            guard let aSrc = try await audio.loadTracks(withMediaType: .audio).first,
                  let aTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            else { throw RedditMediaError.mergeFailed("no audio track") }
            let aRange = try await aSrc.load(.timeRange)
            // Audio often runs a few ms past the video; trim so the clip doesn't end on a black frame.
            let duration = CMTimeMinimum(aRange.duration, vRange.duration)
            try aTrack.insertTimeRange(CMTimeRange(start: aRange.start, duration: duration), of: aSrc, at: .zero)
        }

        try? FileManager.default.removeItem(at: output)
        guard let export = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetPassthrough)
        else { throw RedditMediaError.mergeFailed("no export session") }
        // Puts the index at the front of the file. Photos rejects MP4s without it.
        export.shouldOptimizeForNetworkUse = true
        try await export.export(to: output, as: .mp4)
    }
}
