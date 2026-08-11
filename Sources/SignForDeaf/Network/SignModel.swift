// Network/SignModel.swift

import Foundation

/// Response payload from the `/Translate` endpoint (docs/03-api-contract.md).
struct SignModel: Codable {
    /// Whether the video is ready. `false` means still rendering (keep polling).
    let state: Bool?
    /// Directory the video lives in.
    let baseUrl: String?
    /// File name of the video.
    let name: String?
    /// Translation id — needed for feedback and contact.
    let cid: String?
    /// Backend status flag, carried through but not acted on.
    let st: Bool?
    /// Optional override: translator id the backend actually served under.
    let tid: String?
    /// Optional override: dictionary id the backend actually served under.
    let fdid: String?

    enum CodingKeys: String, CodingKey {
        case state, baseUrl, name, cid, st, tid, fdid
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        state = try container.decodeIfPresent(Bool.self, forKey: .state)
        baseUrl = try container.decodeIfPresent(String.self, forKey: .baseUrl)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        cid = try container.decodeIfPresent(String.self, forKey: .cid)
        st = try container.decodeIfPresent(Bool.self, forKey: .st)
        // The API is not consistent about quoting ids — "44" and 44 must both
        // parse. The SDK keeps ids as strings everywhere.
        tid = SignModel.decodeLenientString(container, forKey: .tid)
        fdid = SignModel.decodeLenientString(container, forKey: .fdid)
    }

    init(
        state: Bool?, baseUrl: String?, name: String?, cid: String?, st: Bool?,
        tid: String? = nil, fdid: String? = nil
    ) {
        self.state = state
        self.baseUrl = baseUrl
        self.name = name
        self.cid = cid
        self.st = st
        self.tid = tid
        self.fdid = fdid
    }

    /// Reads a value that may arrive as a quoted string or a bare number.
    private static func decodeLenientString(
        _ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys
    ) -> String? {
        if let s = try? container.decodeIfPresent(String.self, forKey: key) { return s }
        if let i = try? container.decodeIfPresent(Int.self, forKey: key) { return String(i) }
        if let d = try? container.decodeIfPresent(Double.self, forKey: key) {
            // Whole numbers should not gain a ".0" tail.
            return d == d.rounded() ? String(Int(d)) : String(d)
        }
        return nil
    }

    /// The full video URL (`baseUrl` + `name`), with the first `http:` scheme
    /// rewritten to `https:` for ATS safety (docs/03 §"Assembling the video URL").
    var videoUrl: String? {
        guard let baseUrl = baseUrl, let name = name else { return nil }
        let url = "\(baseUrl)\(name)"
        guard let range = url.range(of: "http:") else { return url }
        return url.replacingCharacters(in: range, with: "https:")
    }
}
