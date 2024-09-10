import Foundation

// MARK: - SignModel
struct SignModel: Codable {
    let state: Bool?
    let baseURL: String?
    let name, cid: String?
    let st: Bool?

    enum CodingKeys: String, CodingKey {
        case state
        case baseURL = "baseUrl"
        case name, cid, st
    }
}

// MARK: SignModel convenience initializers and mutators

extension SignModel {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(SignModel.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        state: Bool?? = nil,
        baseURL: String?? = nil,
        name: String?? = nil,
        cid: String?? = nil,
        st: Bool?? = nil
    ) -> SignModel {
        return SignModel(
            state: state ?? self.state,
            baseURL: baseURL ?? self.baseURL,
            name: name ?? self.name,
            cid: cid ?? self.cid,
            st: st ?? self.st
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - Helper functions for creating encoders and decoders

func newJSONDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    if #available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
        decoder.dateDecodingStrategy = .iso8601
    }
    return decoder
}

func newJSONEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    if #available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
        encoder.dateEncodingStrategy = .iso8601
    }
    return encoder
}
