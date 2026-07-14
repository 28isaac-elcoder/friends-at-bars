import Foundation

actor CatalogStore {
    static let shared = CatalogStore()

    private(set) var venues: [CatalogVenue] = []
    private(set) var listings: [CatalogListing] = []
    private(set) var contentVersion: Int?
    private(set) var wordPack: [String] = []

    private let cacheURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("catalog_venues.json")
    }()

    func refresh(includeTest: Bool = false) async throws {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "is_active", value: "eq.true"),
            URLQueryItem(name: "order", value: "sort_order.asc"),
            URLQueryItem(name: "select", value: "*"),
        ]
        if !includeTest {
            query.append(URLQueryItem(name: "is_test", value: "eq.false"))
        }

        let fetched: [CatalogVenue] = try await SupabaseClient.shared.get(
            path: "rest/v1/catalog_venues",
            query: query
        )
        venues = fetched
        try? saveCache(fetched)

        let listingQuery: [URLQueryItem] = [
            URLQueryItem(name: "is_active", value: "eq.true"),
            URLQueryItem(name: "order", value: "priority.desc"),
            URLQueryItem(name: "select", value: "*"),
        ]
        listings = (try? await SupabaseClient.shared.get(
            path: "rest/v1/catalog_listings",
            query: listingQuery
        )) ?? []

        struct ConfigRow: Decodable {
            struct Value: Decodable { let version: Int? }
            let value: Value
        }
        if let config: [ConfigRow] = try? await SupabaseClient.shared.get(
            path: "rest/v1/catalog_app_config",
            query: [
                URLQueryItem(name: "key", value: "eq.content_version"),
                URLQueryItem(name: "select", value: "value"),
            ]
        ), let version = config.first?.value.version {
            contentVersion = version
        }

        await loadWordPack()
    }

    func loadCachedVenuesIfNeeded() {
        guard venues.isEmpty, let data = try? Data(contentsOf: cacheURL) else { return }
        venues = (try? JSONDecoder().decode([CatalogVenue].self, from: data)) ?? []
    }

    private func saveCache(_ venues: [CatalogVenue]) throws {
        let data = try JSONEncoder().encode(venues)
        try data.write(to: cacheURL, options: .atomic)
    }

    private func loadWordPack() async {
        struct RawPack: Decodable {
            let payload: FlexibleWords
        }
        enum FlexibleWords: Decodable {
            case list([String])
            case buckets([String: [String]])

            init(from decoder: Decoder) throws {
                let c = try decoder.singleValueContainer()
                if let list = try? c.decode([String].self) {
                    self = .list(list)
                    return
                }
                if let obj = try? c.decode([String: [String]].self) {
                    self = .buckets(obj)
                    return
                }
                self = .list([])
            }

            var words: [String] {
                switch self {
                case .list(let w): return w
                case .buckets(let o): return o.values.flatMap { $0 }
                }
            }
        }

        if let rows: [RawPack] = try? await SupabaseClient.shared.get(
            path: "rest/v1/catalog_game_content",
            query: [
                URLQueryItem(name: "game_key", value: "eq.switch-search"),
                URLQueryItem(name: "pack_key", value: "eq.default"),
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "select", value: "payload"),
            ]
        ) {
            wordPack = rows.first?.payload.words ?? []
        }
    }
}

/// Flexible JSON box used only for config version extraction.
enum AnyDecodableBox: Decodable {
    case int(Int)
    case double(Double)
    case string(String)
    case bool(Bool)
    case object([String: AnyDecodableBox])
    case array([AnyDecodableBox])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Int.self) { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([String: AnyDecodableBox].self) { self = .object(v); return }
        if let v = try? c.decode([AnyDecodableBox].self) { self = .array(v); return }
        self = .null
    }

    var object: [String: AnyDecodableBox]? {
        if case .object(let o) = self { return o }
        return nil
    }

    var intValue: Int? {
        switch self {
        case .int(let i): return i
        case .double(let d): return Int(d)
        default: return nil
        }
    }
}
