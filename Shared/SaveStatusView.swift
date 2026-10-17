import SwiftUI

/// Shows where a save is up to. Shared by the app and the Share Extension.
struct SaveStatusView: View {
    let state: SaveModel.State

    var body: some View {
        switch state {
        case .idle:
            EmptyView()
        case let .working(step):
            HStack(spacing: 12) {
                ProgressView()
                Text(step)
            }
        case let .saved(hasAudio):
            Label(hasAudio ? "Saved to Photos with sound" : "Saved to Photos (this post has no sound)",
                  systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }
}
