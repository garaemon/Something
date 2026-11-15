import Foundation

/// A file under one of the file folders that the launcher can open.
struct LocalFile: Hashable {
    /// The folder's own name followed by the path inside the folder, such as
    /// `Downloads/reports/q3.pdf`.
    let name: String
    let url: URL
    /// `name` in lowercase. The folders can hold tens of thousands of files,
    /// so the launcher narrows by this copy instead of lowercasing every name
    /// on each keystroke.
    let lowercasedName: String

    init(name: String, url: URL) {
        self.name = name
        self.url = url
        self.lowercasedName = name.lowercased()
    }
}
