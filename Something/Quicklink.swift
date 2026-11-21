import Foundation

/// A registered link that the launcher opens by name, such as `gh` for a
/// GitHub search. Decoded from `quicklinks.json`.
struct Quicklink: Codable, Hashable {
    let name: String
    /// A URL of any scheme. `{query}` stands for the rest of the launcher query.
    let url: String
    /// The bundle identifier or the path of the application that opens the
    /// URL, or nil for the default application.
    let application: String?

    init(name: String, url: String, application: String? = nil) {
        self.name = name
        self.url = url
        self.application = application
    }

    private static let placeholder = "{query}"

    // Unreserved characters only, so that the text stays inside one query
    // value or path segment.
    private static let queryAllowedCharacters = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
    )

    /// Returns the URL with `query` percent-encoded in place of every
    /// placeholder, or nil when the result is not a valid URL.
    func makeURL(query: String) -> URL? {
        let encodedQuery =
            query.addingPercentEncoding(withAllowedCharacters: Self.queryAllowedCharacters) ?? ""
        return URL(string: url.replacingOccurrences(of: Self.placeholder, with: encodedQuery))
    }
}
