import Foundation

/// The parts of a v.redd.it DASHPlaylist.mpd we need: one file per quality level.
public struct DASHManifest: Equatable, Sendable {
    public struct Stream: Equatable, Sendable {
        public var file: String
        public var height: Int?
        public var bandwidth: Int
    }

    public var video: [Stream] = []
    public var audio: [Stream] = []

    public var bestVideo: Stream? {
        video.max { ($0.height ?? 0, $0.bandwidth) < ($1.height ?? 0, $1.bandwidth) }
    }

    /// Reddit reports the same bandwidth for every audio file, so the number in the
    /// file name (CMAF_AUDIO_128 vs _64) breaks the tie.
    public var bestAudio: Stream? {
        audio.max { ($0.bandwidth, Self.number(in: $0.file)) < ($1.bandwidth, Self.number(in: $1.file)) }
    }

    static func number(in file: String) -> Int {
        file.firstMatch(of: /(\d+)/).flatMap { Int($0.1) } ?? 0
    }

    public init(data: Data) throws {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw parser.parserError ?? RedditMediaError.badManifest
        }
        video = delegate.video
        audio = delegate.audio
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var video: [Stream] = []
        var audio: [Stream] = []
        private var setType: String?
        private var rep: (height: Int?, bandwidth: Int, mime: String?)?
        private var text = ""

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String]) {
            switch name {
            case "AdaptationSet":
                setType = attributes["contentType"] ?? attributes["mimeType"]
            case "Representation":
                rep = (attributes["height"].flatMap(Int.init),
                       attributes["bandwidth"].flatMap(Int.init) ?? 0,
                       attributes["mimeType"])
            case "BaseURL":
                text = ""
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            text += string
        }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                    qualifiedName: String?) {
            switch name {
            case "BaseURL":
                guard let rep else { return }
                let file = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let kind = rep.mime ?? setType ?? ""
                let stream = Stream(file: file, height: rep.height, bandwidth: rep.bandwidth)
                if kind.hasPrefix("audio") { audio.append(stream) } else if kind.hasPrefix("video") { video.append(stream) }
            case "Representation":
                rep = nil
            case "AdaptationSet":
                setType = nil
            default:
                break
            }
        }
    }
}
