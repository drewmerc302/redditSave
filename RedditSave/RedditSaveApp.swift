import SwiftUI

@main
struct RedditSaveApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var model = SaveModel()
    @State private var link = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("In Hydra, Safari, or the Reddit app, tap **Share** on a video post, then **Save Reddit Video**. It lands in Photos with sound.")
                    Text("If it isn't in the list, scroll to the bottom of the share sheet, tap **Edit Actions**, and add it.")
                        .foregroundStyle(.secondary)
                } header: {
                    Text("How to use")
                }

                Section {
                    TextField("Reddit post link", text: $link, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button("Paste") {
                        link = UIPasteboard.general.string ?? ""
                    }
                    Button("Save to Photos") {
                        Task { await model.save(text: link) }
                    }
                    .disabled(link.isEmpty || model.isWorking)
                    SaveStatusView(state: model.state)
                } header: {
                    Text("Or paste a link")
                }
            }
            .navigationTitle("Reddit Save")
        }
    }
}
