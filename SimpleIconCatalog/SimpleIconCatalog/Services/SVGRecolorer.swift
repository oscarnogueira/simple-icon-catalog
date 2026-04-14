import Foundation
import AppKit

/// Recolors a monochrome SVG by rewriting all non-"none" fill/stroke attributes
/// (including inline `style="fill:..."` and bare `currentColor` references) to the
/// requested color, then rasterizes the result to an `NSImage` at the requested size.
enum SVGRecolorer {
    /// Longest side, in points, of the rasterized output.
    static let defaultRenderSize: CGFloat = 1024

    static func recoloredImage(from fileURL: URL, color: NSColor, size: CGFloat = defaultRenderSize) -> NSImage? {
        guard let data = try? Data(contentsOf: fileURL),
              var source = String(data: data, encoding: .utf8) else { return nil }

        let hex = hexString(from: color)
        source = rewriteColors(in: source, targetHex: hex)

        guard let recoloredData = source.data(using: .utf8),
              let image = NSImage(data: recoloredData) else { return nil }

        let aspect = image.size.width / max(image.size.height, 1)
        let targetSize: NSSize = aspect >= 1
            ? NSSize(width: size, height: size / aspect)
            : NSSize(width: size * aspect, height: size)

        let rendered = NSImage(size: targetSize)
        rendered.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: targetSize))
        rendered.unlockFocus()
        return rendered
    }

    // MARK: - Rewriting

    /// Matches `fill="..."`, `stroke="..."`, `fill:...;` or `stroke:...;` inside `style="..."`,
    /// skipping values of `none`, `transparent`, or url(#...) gradients. Also injects a root-level
    /// `fill` on `<svg>` so elements that rely on the SVG default color (black) inherit the target.
    static func rewriteColors(in svg: String, targetHex: String) -> String {
        var result = svg

        // Attribute form: fill="..." / stroke="..."
        for attr in ["fill", "stroke"] {
            let pattern = "\(attr)\\s*=\\s*\"([^\"]*)\""
            result = replaceMatches(in: result, pattern: pattern) { value in
                shouldSkip(value) ? nil : "\(attr)=\"\(targetHex)\""
            }
        }

        // Inline CSS form inside style="...": fill:... ; stroke:... ;
        let stylePattern = "style\\s*=\\s*\"([^\"]*)\""
        result = replaceMatches(in: result, pattern: stylePattern) { styleValue in
            let rewritten = rewriteStyleDeclarations(styleValue, targetHex: targetHex)
            return "style=\"\(rewritten)\""
        }

        // Bare currentColor references outside attributes (e.g. inside <style> blocks)
        result = result.replacingOccurrences(of: "currentColor", with: targetHex, options: .caseInsensitive)

        // Inject root-level fill on <svg> so children that omit fill inherit the target color.
        // If the root already had a fill attribute it was rewritten above and we won't double-add.
        result = ensureRootFill(in: result, targetHex: targetHex)

        return result
    }

    private static func ensureRootFill(in svg: String, targetHex: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "<svg\\b([^>]*)>", options: [.caseInsensitive]) else {
            return svg
        }
        let ns = svg as NSString
        guard let match = regex.firstMatch(in: svg, range: NSRange(location: 0, length: ns.length)) else {
            return svg
        }
        let attrsRange = match.range(at: 1)
        let attrs = ns.substring(with: attrsRange)
        if attrs.range(of: "\\bfill\\s*=", options: [.regularExpression, .caseInsensitive]) != nil {
            return svg  // root already has fill (and was rewritten above)
        }
        let newAttrs = " fill=\"\(targetHex)\"" + attrs
        return (ns.replacingCharacters(in: attrsRange, with: newAttrs)) as String
    }

    private static func rewriteStyleDeclarations(_ style: String, targetHex: String) -> String {
        style.split(separator: ";", omittingEmptySubsequences: false)
            .map { decl -> String in
                let parts = decl.split(separator: ":", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { return String(decl) }
                let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                if (key == "fill" || key == "stroke") && !shouldSkip(value) {
                    return "\(key):\(targetHex)"
                }
                return String(decl)
            }
            .joined(separator: ";")
    }

    private static func shouldSkip(_ value: String) -> Bool {
        let v = value.trimmingCharacters(in: .whitespaces).lowercased()
        return v.isEmpty || v == "none" || v == "transparent" || v.hasPrefix("url(")
    }

    private static func replaceMatches(in source: String, pattern: String, transform: (String) -> String?) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return source
        }
        let ns = source as NSString
        let matches = regex.matches(in: source, range: NSRange(location: 0, length: ns.length))
        var result = source as NSString
        var offset = 0
        for match in matches {
            let adjustedRange = NSRange(location: match.range.location + offset, length: match.range.length)
            let inner = match.range(at: 1)
            let innerValue = ns.substring(with: inner)
            guard let replacement = transform(innerValue) else { continue }
            result = result.replacingCharacters(in: adjustedRange, with: replacement) as NSString
            offset += replacement.count - match.range.length
        }
        return result as String
    }

    // MARK: - Color formatting

    static func hexString(from color: NSColor) -> String {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
