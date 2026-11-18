import Foundation

/// One launcher row that a Python source produced.
struct ScriptItem: Hashable {
    /// The collection that produced the row. An action is valid only for its own
    /// generation and the one before.
    let generation: Int
    /// The name that the Python code gave to `something.add_source`.
    let source: String
    let title: String
    /// The index of the Python action for `PythonInterpreter.runExtensionAction`, or nil when
    /// the row has no action.
    let action: Int?
}

/// A Python source that raised while it listed its rows.
struct ScriptSourceError: Equatable, Decodable {
    let source: String
    let message: String
}

/// What one `something._collect()` call returned, decoded from its JSON string.
struct ScriptCollection: Equatable, Decodable {
    let generation: Int
    let items: [ScriptItem]
    let errors: [ScriptSourceError]

    static let empty = ScriptCollection(generation: 0, items: [], errors: [])

    // The JSON row has no generation, because every row of one collection shares it.
    private struct Row: Decodable {
        let source: String
        let title: String
        let action: Int?
    }

    private enum CodingKeys: String, CodingKey {
        case generation, items, errors
    }

    init(generation: Int, items: [ScriptItem], errors: [ScriptSourceError]) {
        self.generation = generation
        self.items = items
        self.errors = errors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let generation = try container.decode(Int.self, forKey: .generation)
        let rows = try container.decode([Row].self, forKey: .items)
        self.generation = generation
        errors = try container.decode([ScriptSourceError].self, forKey: .errors)
        items = rows.map {
            ScriptItem(
                generation: generation,
                source: $0.source,
                title: $0.title,
                action: $0.action
            )
        }
    }

    /// Decodes the JSON that `something._collect()` returns.
    static func decode(fromJSON json: String) throws -> ScriptCollection {
        try JSONDecoder().decode(ScriptCollection.self, from: Data(json.utf8))
    }
}
