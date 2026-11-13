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
        let patterns = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        let matchedApplications = applications.filter { application in
            let lowercasedName = application.name.lowercased()
            return patterns.allSatisfy { lowercasedName.contains($0) }
        }
        guard let firstPattern = patterns.first else {
            return sortByName(matchedApplications)
        }
        let prefixMatches = matchedApplications.filter {
            $0.name.lowercased().hasPrefix(firstPattern)
        }
        let otherMatches = matchedApplications.filter {
            !$0.name.lowercased().hasPrefix(firstPattern)
        }
        return sortByName(prefixMatches) + sortByName(otherMatches)
    }

    private static func sortByName(_ applications: [LaunchableApplication]) -> [LaunchableApplication] {
        applications.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}
