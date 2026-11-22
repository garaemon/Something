import Foundation

/// The converted value of a query such as `10 km in miles`.
struct UnitConversionResult: Equatable {
    /// The value formatted like a calculator result.
    let valueText: String
    /// The abbreviation of the target unit, such as `mi`.
    let unitSymbol: String
}

/// Converts queries of the form `<number> <unit> (in|to|as) <unit>`.
///
/// The number may be an arithmetic expression, such as `(2 + 3) * 2`.
enum UnitConversion {
    private static let separatorWords: Set<String> = ["in", "to", "as"]

    /// Returns the conversion that `query` asks for, or nil when `query` is
    /// not of that form, names an unknown unit, or mixes dimensions, such as
    /// kilometers and kilograms.
    static func convert(_ query: String) -> UnitConversionResult? {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        // "in" is also inches, as in `10 in in cm`. Try each separator
        // position and keep the first split that parses.
        for separatorIndex in words.indices.dropFirst().dropLast()
        where separatorWords.contains(words[separatorIndex]) {
            let sourceText = words[..<separatorIndex].joined(separator: " ")
            let targetText = words[(separatorIndex + 1)...].joined(separator: " ")
            if let result = convert(sourceText: sourceText, targetUnitName: targetText) {
                return result
            }
        }
        return nil
    }

    private static func convert(
        sourceText: String,
        targetUnitName: String
    ) -> UnitConversionResult? {
        let (numberText, sourceUnitName) = splitNumberAndUnit(sourceText)
        guard let value = Calculator.evaluateOperand(numberText),
            let source = PhysicalUnitCatalog.findUnit(named: sourceUnitName),
            let target = PhysicalUnitCatalog.findUnit(named: targetUnitName),
            source.category == target.category
        else { return nil }
        let convertedValue = Measurement(value: value, unit: source.unit)
            .converted(to: target.unit).value
        guard convertedValue.isFinite else { return nil }
        return UnitConversionResult(
            valueText: Calculator.formatResult(convertedValue),
            unitSymbol: target.symbol
        )
    }

    // The unit starts at the first letter, so that `/` in `36 km/h` stays in
    // the unit while `/` in `10 / 4 km` stays in the number.
    private static func splitNumberAndUnit(_ text: String) -> (number: String, unit: String) {
        let unitStart = text.firstIndex { $0.isLetter || $0 == "\u{00B0}" } ?? text.endIndex
        return (String(text[..<unitStart]), String(text[unitStart...]))
    }
}
