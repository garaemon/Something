import Foundation

/// A file under one of the file folders that the launcher can open.
struct LocalFile: Hashable {
    /// The folder's own name followed by the path inside the folder, such as
    /// `Downloads/reports/q3.pdf`.
    let name: String
    let url: URL
}
