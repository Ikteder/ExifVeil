import Foundation

public enum PrivacyCategory: String, CaseIterable, Codable, Sendable {
    case location
    case captureTime
    case device
    case authorship
    case embeddedNotes

    public var label: String {
        switch self {
        case .location: "Location"
        case .captureTime: "Capture time"
        case .device: "Device"
        case .authorship: "Authorship"
        case .embeddedNotes: "Embedded notes"
        }
    }
}

public enum FindingSeverity: Int, Codable, Comparable, Sendable {
    case low = 1
    case medium = 2
    case high = 3

    public static func < (lhs: FindingSeverity, rhs: FindingSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var label: String {
        switch self {
        case .low: "Review"
        case .medium: "Sensitive"
        case .high: "High sensitivity"
        }
    }
}

public struct MetadataFinding: Identifiable, Hashable, Codable, Sendable {
    public let path: String
    public let category: PrivacyCategory
    public let severity: FindingSeverity
    public let title: String
    public let displayValue: String
    public let explanation: String

    public var id: String { path }

    public init(
        path: String,
        category: PrivacyCategory,
        severity: FindingSeverity,
        title: String,
        displayValue: String,
        explanation: String
    ) {
        self.path = path
        self.category = category
        self.severity = severity
        self.title = title
        self.displayValue = displayValue
        self.explanation = explanation
    }
}

public struct PrivacyReport: Equatable, Codable, Sendable {
    public let metadataLeafCount: Int
    public let findings: [MetadataFinding]

    public init(metadataLeafCount: Int, findings: [MetadataFinding]) {
        self.metadataLeafCount = metadataLeafCount
        self.findings = findings.sorted {
            if $0.severity != $1.severity { return $0.severity > $1.severity }
            if $0.category != $1.category { return $0.category.rawValue < $1.category.rawValue }
            return $0.path < $1.path
        }
    }

    public var riskScore: Int {
        min(100, findings.reduce(0) { partial, finding in
            let weight: Int
            switch finding.severity {
            case .high:
                weight = 30
            case .medium:
                weight = 15
            case .low:
                weight = 5
            }
            return partial + weight
        })
    }

    public var headline: String {
        if findings.isEmpty { return "No known sensitive metadata detected" }
        if riskScore >= 70 { return "High metadata exposure" }
        if riskScore >= 30 { return "Metadata needs review" }
        return "Limited metadata detected"
    }

    public func count(for category: PrivacyCategory) -> Int {
        findings.lazy.filter { $0.category == category }.count
    }
}
