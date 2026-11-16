// Reports trailing closures that hide a closure label, for the rule in STYLE_GUIDE.md.
//
// Usage: closure-label-lint <file-or-directory>...
// Exits with 1 when a violation is found, and with 2 on a usage or read error.
import ClosureLabelLintCore
import Foundation

func listSwiftFiles(under path: String) -> [String] {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
        return []
    }
    guard isDirectory.boolValue else {
        return [path]
    }
    let relativePaths = FileManager.default.enumerator(atPath: path)?.compactMap { $0 as? String }
    return (relativePaths ?? [])
        .filter { $0.hasSuffix(".swift") }
        .sorted()
        .map { (path as NSString).appendingPathComponent($0) }
}

func readSources(at paths: [String]) throws -> [LintSource] {
    try paths.map { path in
        LintSource(path: path, text: try String(contentsOfFile: path, encoding: .utf8))
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard !arguments.isEmpty else {
    FileHandle.standardError.write(Data("usage: closure-label-lint <file-or-directory>...\n".utf8))
    exit(2)
}
let missingPaths = arguments.filter { !FileManager.default.fileExists(atPath: $0) }
guard missingPaths.isEmpty else {
    FileHandle.standardError.write(Data("closure-label-lint: no such path: \(missingPaths)\n".utf8))
    exit(2)
}

do {
    let sources = try readSources(at: arguments.flatMap(listSwiftFiles(under:)))
    let violations = findViolations(in: sources)
    for violation in violations {
        print(violation)
    }
    exit(violations.isEmpty ? 0 : 1)
} catch {
    FileHandle.standardError.write(Data("closure-label-lint: \(error)\n".utf8))
    exit(2)
}
