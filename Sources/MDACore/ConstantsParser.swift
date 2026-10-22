import Foundation

/// Extracts counter data from tesla.com/robotaxi/safety and its scripts.
public enum ConstantsParser {
    /// Reads the counter constants from the script that animates `#robotaxi-fsd-distance`:
    ///
    ///     const robotaxiMilesStart = 3112541;
    ///     const robotaxiStartEpochTime = new Date('2026-10-19T04:59:59Z').getTime();
    ///     const robotaxiMilesPerMillisecond = 0.0009221;
    public static func parseConstants(fromScript script: String) -> CounterConstants? {
        guard
            let start = firstCapture(#/robotaxiMilesStart\s*=\s*([0-9_.]+)/#, in: script)
                .flatMap({ Double($0.replacingOccurrences(of: "_", with: "")) }),
            let dateString = firstCapture(#/robotaxiStartEpochTime\s*=\s*new Date\(\s*['"]([^'"]+)['"]\s*\)/#, in: script),
            let startDate = parseISODate(dateString),
            let rate = firstCapture(#/robotaxiMilesPerMillisecond\s*=\s*([0-9.eE+-]+)/#, in: script)
                .flatMap(Double.init)
        else {
            return nil
        }
        return CounterConstants(startMiles: start, startDate: startDate, milesPerMillisecond: rate)
    }

    /// Reads the server-rendered figure inside `<span id="robotaxi-fsd-distance">`.
    /// The span appears both as markup and JSON-escaped (`id=\"…\"`), so both forms are accepted.
    public static func parseStaticMiles(fromHTML html: String) -> Double? {
        firstCapture(#/robotaxi-fsd-distance\\?"[^>]*>\s*([0-9][0-9,]*)/#, in: html)
            .flatMap { Double($0.replacingOccurrences(of: ",", with: "")) }
    }

    /// Script URLs referenced by the page, in document order, resolved against `baseURL`.
    public static func scriptURLs(fromHTML html: String, baseURL: URL) -> [URL] {
        var seen = Set<URL>()
        return html.matches(of: #/<script\b[^>]*\bsrc="([^"]+)"/#).compactMap { match in
            let src = String(match.output.1).replacingOccurrences(of: "&amp;", with: "&")
            guard let url = URL(string: src, relativeTo: baseURL)?.absoluteURL,
                  seen.insert(url).inserted
            else { return nil }
            return url
        }
    }

    private static func firstCapture(_ regex: Regex<(Substring, Substring)>, in text: String) -> String? {
        text.firstMatch(of: regex).map { String($0.output.1) }
    }

    private static func parseISODate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: string)
    }
}
