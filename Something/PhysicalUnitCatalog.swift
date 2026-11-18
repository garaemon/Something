import Foundation

/// The physical quantity that a unit measures. Only units of one category
/// convert into each other.
enum PhysicalUnitCategory {
    case length
    case mass
    case temperature
    case volume
    case speed
    case area
    case dataSize
    case duration
}

/// One unit that the launcher converts, with the names that the user may type
/// for it.
struct PhysicalUnitDefinition {
    let category: PhysicalUnitCategory
    /// The abbreviation that the result row shows, such as `km`.
    let symbol: String
    let unit: Dimension
    /// Lowercase names, such as `kilometers`. Each name belongs to one unit.
    let aliases: [String]
}

/// The units for `UnitConversion`, as data in the style of `WebSearchEngine`.
/// Foundation's `Dimension` subclasses hold the conversion coefficients.
enum PhysicalUnitCatalog {
    /// Returns the unit that `name` stands for, ignoring case and surrounding
    /// whitespace, or nil when no unit has that name.
    static func findUnit(named name: String) -> PhysicalUnitDefinition? {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return definitionsByAlias[normalizedName]
    }

    static let definitions: [PhysicalUnitDefinition] =
        lengthUnits + massUnits + temperatureUnits + volumeUnits + speedUnits + areaUnits
        + dataUnits + durationUnits

    private static let definitionsByAlias: [String: PhysicalUnitDefinition] = {
        var table: [String: PhysicalUnitDefinition] = [:]
        for definition in definitions {
            for alias in definition.aliases {
                table[alias] = definition
            }
        }
        return table
    }()

    private static let lengthUnits = [
        define(
            .length,
            "km",
            UnitLength.kilometers,
            "km",
            "kilometer",
            "kilometers",
            "kilometre",
            "kilometres"
        ),
        define(.length, "m", UnitLength.meters, "m", "meter", "meters", "metre", "metres"),
        define(
            .length,
            "cm",
            UnitLength.centimeters,
            "cm",
            "centimeter",
            "centimeters",
            "centimetre",
            "centimetres"
        ),
        define(
            .length,
            "mm",
            UnitLength.millimeters,
            "mm",
            "millimeter",
            "millimeters",
            "millimetre",
            "millimetres"
        ),
        define(.length, "mi", UnitLength.miles, "mi", "mile", "miles"),
        define(.length, "yd", UnitLength.yards, "yd", "yds", "yard", "yards"),
        define(.length, "ft", UnitLength.feet, "ft", "foot", "feet"),
        define(.length, "in", UnitLength.inches, "in", "inch", "inches"),
    ]

    // Foundation rounds the pound and the ounce to six digits, so these two
    // use the exact definitions of the international avoirdupois units.
    private static let massUnits = [
        define(.mass, "kg", UnitMass.kilograms, "kg", "kilogram", "kilograms"),
        define(.mass, "g", UnitMass.grams, "g", "gram", "grams"),
        define(.mass, "mg", UnitMass.milligrams, "mg", "milligram", "milligrams"),
        define(
            .mass,
            "lb",
            UnitMass(symbol: "lb", converter: UnitConverterLinear(coefficient: 0.453_592_37)),
            "lb",
            "lbs",
            "pound",
            "pounds"
        ),
        define(
            .mass,
            "oz",
            UnitMass(symbol: "oz", converter: UnitConverterLinear(coefficient: 0.028_349_523_125)),
            "oz",
            "ounce",
            "ounces"
        ),
        define(.mass, "t", UnitMass.metricTons, "tonne", "tonnes"),
    ]

    private static let temperatureUnits = [
        define(.temperature, "\u{00B0}C", UnitTemperature.celsius, "c", "celsius", "degc"),
        define(.temperature, "\u{00B0}F", UnitTemperature.fahrenheit, "f", "fahrenheit", "degf"),
        define(.temperature, "K", UnitTemperature.kelvin, "k", "kelvin"),
    ]

    // Foundation rounds its US customary volumes to six digits, so these use
    // exact multiples of the US fluid ounce (29.5735295625 ml). The cup is
    // the US customary cup of 8 fluid ounces, not Foundation's metric cup.
    private static let volumeUnits = [
        define(.volume, "l", UnitVolume.liters, "l", "liter", "liters", "litre", "litres"),
        define(
            .volume,
            "ml",
            UnitVolume.milliliters,
            "ml",
            "milliliter",
            "milliliters",
            "millilitre",
            "millilitres"
        ),
        define(.volume, "gal", makeUSVolume("gal", fluidOunces: 128), "gal", "gallon", "gallons"),
        define(.volume, "qt", makeUSVolume("qt", fluidOunces: 32), "qt", "quart", "quarts"),
        define(.volume, "pt", makeUSVolume("pt", fluidOunces: 16), "pt", "pint", "pints"),
        define(.volume, "cup", makeUSVolume("cup", fluidOunces: 8), "cup", "cups"),
        define(
            .volume,
            "fl oz",
            makeUSVolume("fl oz", fluidOunces: 1),
            "fl oz",
            "floz",
            "fluid ounce",
            "fluid ounces"
        ),
        define(
            .volume,
            "tbsp",
            makeUSVolume("tbsp", fluidOunces: 0.5),
            "tbsp",
            "tablespoon",
            "tablespoons"
        ),
        define(
            .volume,
            "tsp",
            makeUSVolume("tsp", fluidOunces: 1.0 / 6.0),
            "tsp",
            "teaspoon",
            "teaspoons"
        ),
    ]

    // Foundation rounds km/h and knots to six digits, so these two use exact
    // coefficients in meters per second.
    private static let speedUnits = [
        define(.speed, "m/s", UnitSpeed.metersPerSecond, "m/s", "mps"),
        define(
            .speed,
            "km/h",
            UnitSpeed(symbol: "km/h", converter: UnitConverterLinear(coefficient: 1.0 / 3.6)),
            "km/h",
            "kmh",
            "kph"
        ),
        define(.speed, "mph", UnitSpeed.milesPerHour, "mph", "mi/h"),
        define(
            .speed,
            "kn",
            UnitSpeed(symbol: "kn", converter: UnitConverterLinear(coefficient: 1852.0 / 3600.0)),
            "kn",
            "kt",
            "knot",
            "knots"
        ),
    ]

    private static let areaUnits = [
        define(
            .area,
            "m\u{00B2}",
            UnitArea.squareMeters,
            "m2",
            "sqm",
            "square meter",
            "square meters"
        ),
        define(
            .area,
            "km\u{00B2}",
            UnitArea.squareKilometers,
            "km2",
            "sqkm",
            "square kilometer",
            "square kilometers"
        ),
        define(
            .area,
            "ft\u{00B2}",
            UnitArea.squareFeet,
            "ft2",
            "sqft",
            "square foot",
            "square feet"
        ),
        define(
            .area,
            "mi\u{00B2}",
            UnitArea.squareMiles,
            "mi2",
            "sqmi",
            "square mile",
            "square miles"
        ),
        define(.area, "ac", UnitArea.acres, "ac", "acre", "acres"),
        define(.area, "ha", UnitArea.hectares, "ha", "hectare", "hectares"),
    ]

    private static let dataUnits = [
        define(.dataSize, "bit", UnitInformationStorage.bits, "bit", "bits"),
        define(.dataSize, "B", UnitInformationStorage.bytes, "byte", "bytes"),
        define(.dataSize, "kB", UnitInformationStorage.kilobytes, "kb", "kilobyte", "kilobytes"),
        define(.dataSize, "MB", UnitInformationStorage.megabytes, "mb", "megabyte", "megabytes"),
        define(.dataSize, "GB", UnitInformationStorage.gigabytes, "gb", "gigabyte", "gigabytes"),
        define(.dataSize, "TB", UnitInformationStorage.terabytes, "tb", "terabyte", "terabytes"),
        define(.dataSize, "KiB", UnitInformationStorage.kibibytes, "kib", "kibibyte", "kibibytes"),
        define(.dataSize, "MiB", UnitInformationStorage.mebibytes, "mib", "mebibyte", "mebibytes"),
        define(.dataSize, "GiB", UnitInformationStorage.gibibytes, "gib", "gibibyte", "gibibytes"),
        define(.dataSize, "TiB", UnitInformationStorage.tebibytes, "tib", "tebibyte", "tebibytes"),
    ]

    // Foundation's UnitDuration stops at hours, so days and weeks are built
    // from seconds.
    private static let durationUnits = [
        define(.duration, "ms", UnitDuration.milliseconds, "ms", "millisecond", "milliseconds"),
        define(.duration, "s", UnitDuration.seconds, "s", "sec", "secs", "second", "seconds"),
        define(.duration, "min", UnitDuration.minutes, "min", "mins", "minute", "minutes"),
        define(.duration, "h", UnitDuration.hours, "h", "hr", "hrs", "hour", "hours"),
        define(
            .duration,
            "d",
            UnitDuration(symbol: "d", converter: UnitConverterLinear(coefficient: 86_400)),
            "d",
            "day",
            "days"
        ),
        define(
            .duration,
            "wk",
            UnitDuration(symbol: "wk", converter: UnitConverterLinear(coefficient: 604_800)),
            "wk",
            "week",
            "weeks"
        ),
    ]

    private static let litersPerUSFluidOunce = 0.029_573_529_562_5

    private static func makeUSVolume(_ symbol: String, fluidOunces: Double) -> UnitVolume {
        let converter = UnitConverterLinear(coefficient: litersPerUSFluidOunce * fluidOunces)
        return UnitVolume(symbol: symbol, converter: converter)
    }

    private static func define(
        _ category: PhysicalUnitCategory,
        _ symbol: String,
        _ unit: Dimension,
        _ aliases: String...
    ) -> PhysicalUnitDefinition {
        PhysicalUnitDefinition(category: category, symbol: symbol, unit: unit, aliases: aliases)
    }
}
