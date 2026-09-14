import Foundation
import ImageIO

public enum MetadataInspectionError: Error, Equatable, LocalizedError {
    case invalidImageData
    case missingImageFrame

    public var errorDescription: String? {
        switch self {
        case .invalidImageData: "The selected bytes are not a readable image."
        case .missingImageFrame: "The image does not contain a readable still frame."
        }
    }
}

public struct MetadataInspector: Sendable {
    public init() {}

    public func inspect(data: Data) throws -> PrivacyReport {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw MetadataInspectionError.invalidImageData
        }
        guard CGImageSourceGetCount(source) > 0 else {
            throw MetadataInspectionError.missingImageFrame
        }

        let raw = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        let leaves = flatten(raw)
        let findings = leaves.compactMap { classify(path: $0.path, value: $0.value) }
        return PrivacyReport(metadataLeafCount: leaves.count, findings: findings)
    }

    private func flatten(_ dictionary: [String: Any], prefix: String = "") -> [(path: String, value: Any)] {
        dictionary.keys.sorted().flatMap { key -> [(path: String, value: Any)] in
            let path = prefix.isEmpty ? key : "\(prefix).\(key)"
            let value = dictionary[key] as Any
            if let nested = value as? [String: Any] {
                return flatten(nested, prefix: path)
            }
            if let nested = value as? NSDictionary {
                var converted: [String: Any] = [:]
                for (childKey, childValue) in nested {
                    converted[String(describing: childKey)] = childValue
                }
                return flatten(converted, prefix: path)
            }
            return [(path, value)]
        }
    }

    private func classify(path: String, value: Any) -> MetadataFinding? {
        let key = path.lowercased()

        if key.contains("{gps}") || key.contains("gps.") {
            return finding(
                path: path,
                category: .location,
                severity: .high,
                title: "Location coordinate",
                value: "Present (exact value hidden)",
                explanation: "GPS metadata can reveal where the photo was captured."
            )
        }

        if key.contains("datetime") || key.contains("datecreated") || key.contains("digitalcreationdate") {
            return finding(
                path: path,
                category: .captureTime,
                severity: .medium,
                title: "Capture timestamp",
                value: safeDisplay(value),
                explanation: "Capture times can reveal routines, travel, or event attendance."
            )
        }

        if key.contains("serialnumber") || key.contains("ownername") {
            return finding(
                path: path,
                category: .device,
                severity: .high,
                title: "Device identifier",
                value: safeDisplay(value),
                explanation: "A device or lens identifier may link photos to the same equipment or owner."
            )
        }

        if hasTerminalKey(key, in: ["make", "model", "software", "lensmodel"]) {
            return finding(
                path: path,
                category: .device,
                severity: .medium,
                title: "Device detail",
                value: safeDisplay(value),
                explanation: "Camera and software details can contribute to device fingerprinting."
            )
        }

        if hasTerminalKey(key, in: ["artist", "copyright", "by-line", "creator", "credit"]) || key.contains("contact") {
            return finding(
                path: path,
                category: .authorship,
                severity: key.contains("contact") ? .high : .medium,
                title: "Author or contact detail",
                value: safeDisplay(value),
                explanation: "Authorship fields can expose a name, organization, or contact detail."
            )
        }

        if key.contains("usercomment") || hasTerminalKey(key, in: ["imagedescription", "caption", "keywords", "headline"]) {
            return finding(
                path: path,
                category: .embeddedNotes,
                severity: .low,
                title: "Embedded note",
                value: safeDisplay(value),
                explanation: "Comments, captions, or keywords may reveal context not visible in the pixels."
            )
        }

        return nil
    }

    private func hasTerminalKey(_ path: String, in names: [String]) -> Bool {
        names.contains { path == $0 || path.hasSuffix(".\($0)") }
    }

    private func finding(
        path: String,
        category: PrivacyCategory,
        severity: FindingSeverity,
        title: String,
        value: String,
        explanation: String
    ) -> MetadataFinding {
        MetadataFinding(
            path: path,
            category: category,
            severity: severity,
            title: title,
            displayValue: value,
            explanation: explanation
        )
    }

    private func safeDisplay(_ value: Any) -> String {
        let text = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return "Present" }
        if text.count <= 80 { return text }
        return String(text.prefix(77)) + "..."
    }
}

