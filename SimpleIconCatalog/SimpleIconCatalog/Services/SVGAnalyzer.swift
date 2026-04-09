import Foundation

struct SVGAnalysisResult {
    let width: Int
    let height: Int
    let isMonochrome: Bool
}

struct SVGAnalyzer {
    enum SVGError: Error {
        case parseError(String)
        case noDimensions
    }

    func analyze(fileURL: URL) throws -> SVGAnalysisResult {
        let data = try Data(contentsOf: fileURL)
        let parser = SVGXMLParser(data: data)
        try parser.parse()

        guard let width = parser.width, let height = parser.height else {
            throw SVGError.noDimensions
        }

        return SVGAnalysisResult(
            width: width,
            height: height,
            isMonochrome: parser.isMonochrome
        )
    }
}

private class SVGXMLParser: NSObject, XMLParserDelegate {
    private let parser: XMLParser
    var width: Int?
    var height: Int?
    private var colors: Set<String> = []
    private var parseError: Error?

    private let monochromeColors: Set<String> = [
        "#000000", "#000", "black",
        "#ffffff", "#fff", "white",
        "none", "currentcolor", "inherit", ""
    ]

    init(data: Data) {
        self.parser = XMLParser(data: data)
        super.init()
        self.parser.delegate = self
    }

    func parse() throws {
        guard parser.parse() else {
            throw parseError ?? SVGAnalyzer.SVGError.parseError("Unknown parse error")
        }
    }

    var isMonochrome: Bool {
        colors.allSatisfy { monochromeColors.contains($0.lowercased().trimmingCharacters(in: .whitespaces)) }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        if elementName.lowercased() == "svg" {
            if let w = attributes["width"], let h = attributes["height"] {
                self.width = Int(Double(w.replacingOccurrences(of: "px", with: "")) ?? 0)
                self.height = Int(Double(h.replacingOccurrences(of: "px", with: "")) ?? 0)
            }
            if (self.width == nil || self.width == 0),
               let viewBox = attributes["viewBox"] {
                let parts = viewBox.split(separator: " ").map(String.init)
                if parts.count == 4 {
                    self.width = Int(Double(parts[2]) ?? 0)
                    self.height = Int(Double(parts[3]) ?? 0)
                }
            }
        }

        if let fill = attributes["fill"] { colors.insert(fill) }
        if let stroke = attributes["stroke"] { colors.insert(stroke) }

        // Extract colors from inline style attribute (e.g. style="fill: #FF0000; stroke: blue")
        if let style = attributes["style"] {
            for property in style.split(separator: ";") {
                let parts = property.split(separator: ":", maxSplits: 1)
                guard parts.count == 2 else { continue }
                let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                if key == "fill" || key == "stroke" {
                    colors.insert(value)
                }
            }
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred error: Error) {
        parseError = SVGAnalyzer.SVGError.parseError(error.localizedDescription)
    }
}
