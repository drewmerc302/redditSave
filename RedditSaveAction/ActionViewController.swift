import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Entry point for the "Save Reddit Video" share sheet action.
final class ActionViewController: UIViewController {
    private let model = SaveModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        let root = ActionView(model: model) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
        Task {
            let text = await Self.sharedText(from: providers)
            await model.save(text: text)
        }
    }

    /// Apps share a post as a URL, as text containing a URL, or both. Collect everything
    /// and let PostLink pick out the Reddit link.
    private static func sharedText(from providers: [NSItemProvider]) async -> String {
        var pieces: [String] = []
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
               let url = await load(URL.self, from: provider) {
                pieces.append(url.absoluteString)
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
               let text = await load(String.self, from: provider) {
                pieces.append(text)
            }
        }
        return pieces.joined(separator: " ")
    }

    private static func load<T: _ObjectiveCBridgeable & Sendable>(_ type: T.Type, from provider: NSItemProvider) async -> T?
        where T._ObjectiveCType: NSItemProviderReading {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: type) { value, _ in
                continuation.resume(returning: value)
            }
        }
    }
}

private struct ActionView: View {
    let model: SaveModel
    let close: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                SaveStatusView(state: model.state)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .navigationTitle("Save Reddit Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.isWorking ? "Cancel" : "Done", action: close)
                }
            }
        }
        .task(id: model.state) {
            // Close by itself after a successful save; leave errors up so they can be read.
            if case .saved = model.state {
                try? await Task.sleep(for: .seconds(1.2))
                close()
            }
        }
    }
}
