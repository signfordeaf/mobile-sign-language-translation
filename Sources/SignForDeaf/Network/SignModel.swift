// Network/SignModel.swift

import Foundation

/// Response payload from the `/Translate` endpoint.
struct SignModel: Codable {
    let state: Bool?
    let baseUrl: String?
    let name: String?
    let cid: String?
    let st: Bool?

    enum CodingKeys: String, CodingKey {
        case state
        case baseUrl
        case name
        case cid
        case st
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        state = try container.decodeIfPresent(Bool.self, forKey: .state)
        baseUrl = try container.decodeIfPresent(String.self, forKey: .baseUrl)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        cid = try container.decodeIfPresent(String.self, forKey: .cid)
        st = try container.decodeIfPresent(Bool.self, forKey: .st)
    }

    init(state: Bool?, baseUrl: String?, name: String?, cid: String?, st: Bool?) {
        self.state = state
        self.baseUrl = baseUrl
        self.name = name
        self.cid = cid
        self.st = st
    }

    /// The full video URL (`baseUrl` + `name`), upgraded to https for ATS safety.
    /// This is the single place http→https rewriting happens.
    var videoUrl: String? {
        guard let baseUrl = baseUrl, let name = name else { return nil }
        let url = "\(baseUrl)\(name)"
        return url.replacingOccurrences(of: "http://", with: "https://")
    }
}
