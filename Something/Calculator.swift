import Foundation

/// Evaluates arithmetic typed into the launcher, such as `10 + 30`.
///
/// Supports `+`, `-`, `*` (or `×`), `/` (or `÷`), `%` (remainder), `^`
/// (power, right-associative), unary minus, and parentheses.
enum Calculator {
    /// Returns the value of `expression`, or nil when `expression` is not
    /// arithmetic, holds no operator, or has a non-finite value such as a
    /// division by zero.
    static func evaluate(_ expression: String) -> Double? {
        guard let tokens = tokenize(expression),
            tokens.contains(where: { if case .symbol = $0 { true } else { false } })
        else { return nil }
        var parser = CalculatorParser(tokens: tokens)
        guard let value = parser.parseExpression(), parser.isAtEnd, value.isFinite else { return nil }
        return value
    }

    /// Returns `value` as the launcher shows it: integers without a decimal
    /// point, and fractions rounded to 12 significant digits so that
    /// `0.1 + 0.2` reads `0.3`.
    static func formatResult(_ value: Double) -> String {
        // Doubles hold every integer exactly up to 2^53, about 9e15.
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int64(value))
        }
        return String(format: "%.12g", value)
    }

    private static func tokenize(_ expression: String) -> [CalculatorToken]? {
        var tokens: [CalculatorToken] = []
        var remaining = Substring(expression)
        while let character = remaining.first {
            if character.isWhitespace {
                remaining = remaining.dropFirst()
            } else if character.isASCII, character.isNumber || character == "." {
                let numberText = remaining.prefix { $0.isASCII && ($0.isNumber || $0 == ".") }
                guard let number = Double(numberText) else { return nil }
                tokens.append(.number(number))
                remaining = remaining.dropFirst(numberText.count)
            } else if let symbol = normalizeSymbol(character) {
                tokens.append(.symbol(symbol))
                remaining = remaining.dropFirst()
            } else {
                return nil
            }
        }
        return tokens
    }

    private static func normalizeSymbol(_ character: Character) -> Character? {
        switch character {
        case "×": "*"
        case "÷": "/"
        case "+", "-", "*", "/", "%", "^", "(", ")": character
        default: nil
        }
    }
}

private enum CalculatorToken: Equatable {
    case number(Double)
    case symbol(Character)
}

/// Recursive descent parser over the grammar:
///
///     expression = term (("+" | "-") term)*
///     term       = unary (("*" | "/" | "%") unary)*
///     unary      = "-" unary | power
///     power      = primary ("^" unary)?
///     primary    = number | "(" expression ")"
private struct CalculatorParser {
    let tokens: [CalculatorToken]
    private var position = 0

    init(tokens: [CalculatorToken]) {
        self.tokens = tokens
    }

    var isAtEnd: Bool { position == tokens.count }

    mutating func parseExpression() -> Double? {
        guard var value = parseTerm() else { return nil }
        while let symbol = consumeSymbol(in: "+-") {
            guard let rightValue = parseTerm() else { return nil }
            value = symbol == "+" ? value + rightValue : value - rightValue
        }
        return value
    }

    private mutating func parseTerm() -> Double? {
        guard var value = parseUnary() else { return nil }
        while let symbol = consumeSymbol(in: "*/%") {
            guard let rightValue = parseUnary() else { return nil }
            switch symbol {
            case "*": value *= rightValue
            case "/": value /= rightValue
            default: value = value.truncatingRemainder(dividingBy: rightValue)
            }
        }
        return value
    }

    private mutating func parseUnary() -> Double? {
        if consumeSymbol(in: "-") != nil {
            return parseUnary().map { -$0 }
        }
        return parsePower()
    }

    // The exponent goes through parseUnary so that `2 ^ -1` and the
    // right-associative `2 ^ 3 ^ 2` both parse.
    private mutating func parsePower() -> Double? {
        guard let base = parsePrimary() else { return nil }
        guard consumeSymbol(in: "^") != nil else { return base }
        return parseUnary().map { pow(base, $0) }
    }

    private mutating func parsePrimary() -> Double? {
        guard position < tokens.count else { return nil }
        let token = tokens[position]
        position += 1
        switch token {
        case .number(let value):
            return value
        case .symbol("("):
            guard let value = parseExpression(), consumeSymbol(in: ")") != nil else { return nil }
            return value
        case .symbol:
            return nil
        }
    }

    private mutating func consumeSymbol(in candidates: String) -> Character? {
        guard position < tokens.count, case .symbol(let symbol) = tokens[position],
            candidates.contains(symbol)
        else { return nil }
        position += 1
        return symbol
    }
}
