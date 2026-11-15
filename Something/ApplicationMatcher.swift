import Foundation

/// Narrows applications by a query in the style of Emacs anything.el.
enum ApplicationMatcher {
    /// Returns the applications whose names contain every whitespace-separated
    /// pattern in `query`, ignoring case.
    ///
    /// Names that start with the first pattern come first. Ties are ordered by
    /// name. An empty query returns every application.
    static func filterApplications(
        _ applications: [LaunchableApplication], matching query: String
    ) -> [LaunchableApplication] {
        filterItems(applications, matching: query, name: \.name)
    }

    /// Returns the items whose `name` contains every whitespace-separated
    /// pattern in `query`, ordered as `filterApplications` orders applications.
    static func filterItems<Item>(
        _ items: [Item], matching query: String, name: (Item) -> String
    ) -> [Item] {
        let patterns = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        let matchedItems = items.filter { item in
            let lowercasedName = name(item).lowercased()
            return patterns.allSatisfy { lowercasedName.contains($0) }
        }
        guard let firstPattern = patterns.first else {
            return sortByName(matchedItems, name: name)
        }
        let prefixMatches = matchedItems.filter { name($0).lowercased().hasPrefix(firstPattern) }
        let otherMatches = matchedItems.filter { !name($0).lowercased().hasPrefix(firstPattern) }
        return sortByName(prefixMatches, name: name) + sortByName(otherMatches, name: name)
    }

    private static func sortByName<Item>(_ items: [Item], name: (Item) -> String) -> [Item] {
        items.sorted { name($0).localizedStandardCompare(name($1)) == .orderedAscending }
    }
}
