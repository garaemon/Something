import Foundation

/// A web search service that the launcher offers for any non-empty query.
/// Adding a service means adding a value, not a type.
struct WebSearchEngine: Hashable {
    /// The verb phrase before the query in the row, such as "Search Google".
    let actionLabel: String
    /// The SF Symbol that the row shows as its icon.
    let symbolName: String
    let baseURL: String
    /// Parameters that precede the query parameter, such as a mode switch.
    let fixedQueryItems: [URLQueryItem]
    let queryParameterName: String

    static let google = WebSearchEngine(
        actionLabel: "Search Google", symbolName: "magnifyingglass",
        baseURL: "https://www.google.com/search", fixedQueryItems: [], queryParameterName: "q")

    // udm=50 switches Google Search to AI Mode.
    static let googleAIMode = WebSearchEngine(
        actionLabel: "Ask Google AI Mode", symbolName: "sparkles",
        baseURL: "https://www.google.com/search",
        fixedQueryItems: [URLQueryItem(name: "udm", value: "50")], queryParameterName: "q")

    /// The engines that the launcher lists, in display order.
    static let launcherEngines: [WebSearchEngine] = [.google, .googleAIMode]
}

/// A query to send to one web search engine.
struct WebSearch: Hashable {
    let engine: WebSearchEngine
    let query: String

    // Servers decode `+` in a query as a space, but URLQueryItem leaves it
    // unescaped, so escape it along with the separators of the query string.
    private static let queryValueAllowedCharacters = CharacterSet.urlQueryAllowed
        .subtracting(CharacterSet(charactersIn: "+&=#"))

    /// The text of the launcher row, such as "Search Google: swift".
    var title: String { "\(engine.actionLabel): \(query)" }

    /// The search results page for the query, or nil when the engine's base
    /// URL is malformed.
    var url: URL? {
        guard var components = URLComponents(string: engine.baseURL) else { return nil }
        let queryItems = engine.fixedQueryItems + [URLQueryItem(name: engine.queryParameterName, value: query)]
        components.percentEncodedQueryItems = queryItems.map(Self.encodeQueryItem)
        return components.url
    }

    private static func encodeQueryItem(_ item: URLQueryItem) -> URLQueryItem {
        let encodedValue = item.value?.addingPercentEncoding(withAllowedCharacters: queryValueAllowedCharacters)
        return URLQueryItem(name: item.name, value: encodedValue)
    }
}
