import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ImageSanitizationError: Error, Equatable, LocalizedError {
    case invalidImageData
    case animatedImageUnsupported
    case decodeFailed
    case encodeFailed
    case sensitiveMetadataRemained

    public var errorDescription: String? {
        switch self {
        case .invalidImageData: "The selected bytes are not a readable image."
        case .animatedImageUnsupported: "ExifVeil 1.0 supports one still-image frame at a time."
        case .decodeFailed: "The image pixels could not be decoded."
        case .encodeFailed: "A sanitized image could not be created."
        case .sensitiveMetadataRemained: "Output validation found sensitive metadata, so sharing was blocked."
        }
    }
}

public struct SanitizedImage: Sendable {
    public let data: Data
    public let originalReport: PrivacyReport
    public let sanitizedReport: PrivacyReport
    public let formatIdentifier: String
    public let pixelWidth: Int
    public let pixelHeight: Int

    public var suggestedFileExtension: String {
        formatIdentifier == UTType.png.identifier ? "png" : "jpg"
    }
}

public struct ImageSanitizer: Sendable {
    private let inspector: MetadataInspector

    public init(inspector: MetadataInspector = MetadataInspector()) {
        self.inspector = inspector
    }

    public func sanitize(data: Data) throws -> SanitizedImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImageSanitizationError.invalidImageData
        }
        guard CGImageSourceGetCount(source) == 1 else {
            throw ImageSanitizationError.animatedImageUnsupported
        }
        guard let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ImageSanitizationError.decodeFailed
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        let orientation = (properties[kCGImagePropertyOrientation as String] as? NSNumber)?.int32Value ?? 1
        let oriented = CIImage(cgImage: decoded).oriented(forExifOrientation: orientation)
        let context = CIContext(options: [.cacheIntermediates: false])
        guard let rendered = context.createCGImage(oriented, from: oriented.extent.integral) else {
            throw ImageSanitizationError.decodeFailed
        }

        let sourceType = CGImageSourceGetType(source) as String?
        let outputType = sourceType == UTType.png.identifier ? UTType.png.identifier : UTType.jpeg.identifier
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            outputType as CFString,
            1,
            nil
        ) else {
            throw ImageSanitizationError.encodeFailed
        }

        let outputProperties: [CFString: Any] = outputType == UTType.jpeg.identifier
            ? [kCGImageDestinationLossyCompressionQuality: 0.92]
            : [:]
        CGImageDestinationAddImage(destination, rendered, outputProperties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageSanitizationError.encodeFailed
        }

        let sanitizedData = output as Data
        let originalReport = try inspector.inspect(data: data)
        let sanitizedReport = try inspector.inspect(data: sanitizedData)
        guard sanitizedReport.findings.isEmpty else {
            throw ImageSanitizationError.sensitiveMetadataRemained
        }

        return SanitizedImage(
            data: sanitizedData,
            originalReport: originalReport,
            sanitizedReport: sanitizedReport,
            formatIdentifier: outputType,
            pixelWidth: rendered.width,
            pixelHeight: rendered.height
        )
    }
}

