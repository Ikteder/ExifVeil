import CoreGraphics
import ImageIO
import XCTest
import UniformTypeIdentifiers
#if canImport(ExifVeilCore)
@testable import ExifVeilCore
#else
@testable import ExifVeil
#endif

final class ExifVeilCoreTests: XCTestCase {
    func testFixtureExposesEverySupportedCategory() throws {
        let report = try MetadataInspector().inspect(data: try FixtureFactory.makeJPEG())

        XCTAssertGreaterThanOrEqual(report.count(for: .location), 2)
        XCTAssertGreaterThanOrEqual(report.count(for: .captureTime), 1)
        XCTAssertGreaterThanOrEqual(report.count(for: .device), 2)
        XCTAssertGreaterThanOrEqual(report.count(for: .authorship), 1)
        XCTAssertGreaterThanOrEqual(report.count(for: .embeddedNotes), 1)
        XCTAssertEqual(report.riskScore, 100)
        XCTAssertEqual(report.headline, "High metadata exposure")
    }

    func testLocationValuesAreRedacted() throws {
        let report = try MetadataInspector().inspect(data: try FixtureFactory.makeJPEG())
        let locations = report.findings.filter { $0.category == .location }

        XCTAssertFalse(locations.isEmpty)
        XCTAssertTrue(locations.allSatisfy { $0.displayValue == "Present (exact value hidden)" })
        XCTAssertFalse(locations.contains { $0.displayValue.contains("40.015") })
    }

    func testSanitizerRemovesKnownSensitiveMetadata() throws {
        let result = try ImageSanitizer().sanitize(data: try FixtureFactory.makeJPEG())

        XCTAssertFalse(result.originalReport.findings.isEmpty)
        XCTAssertTrue(result.sanitizedReport.findings.isEmpty)
        XCTAssertEqual(result.sanitizedReport.riskScore, 0)
        XCTAssertEqual(result.formatIdentifier, UTType.jpeg.identifier)
        XCTAssertFalse(result.data.isEmpty)
    }

    func testSanitizerNormalizesOrientationIntoPixels() throws {
        let result = try ImageSanitizer().sanitize(data: try FixtureFactory.makeJPEG(orientation: 6))

        XCTAssertEqual(result.pixelWidth, 3)
        XCTAssertEqual(result.pixelHeight, 2)
        let properties = try XCTUnwrap(
            CGImageSourceCreateWithData(result.data as CFData, nil)
                .flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [String: Any] }
        )
        XCTAssertNil(properties[kCGImagePropertyOrientation as String])
    }

    func testMalformedBytesAreRejected() {
        XCTAssertThrowsError(try MetadataInspector().inspect(data: Data("not an image".utf8))) { error in
            XCTAssertEqual(error as? MetadataInspectionError, .invalidImageData)
        }
        XCTAssertThrowsError(try ImageSanitizer().sanitize(data: Data("not an image".utf8))) { error in
            XCTAssertEqual(error as? ImageSanitizationError, .invalidImageData)
        }
    }

    func testScoreIsBounded() {
        let findings = (0..<20).map {
            MetadataFinding(
                path: "GPS.\($0)",
                category: .location,
                severity: .high,
                title: "Location",
                displayValue: "Present",
                explanation: "Test"
            )
        }
        XCTAssertEqual(PrivacyReport(metadataLeafCount: 20, findings: findings).riskScore, 100)
    }
}

private enum FixtureFactory {
    static func makeJPEG(orientation: Int = 1) throws -> Data {
        let width = 2
        let height = 3
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(CGColor(red: 0.15, green: 0.35, blue: 0.85, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 3))
        let image = try XCTUnwrap(context.makeImage())

        let data = NSMutableData()
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
        )
        let exif: [CFString: Any] = [
            kCGImagePropertyExifDateTimeOriginal: "2026:09:14 10:00:00",
            kCGImagePropertyExifUserComment: "Back door entry code reminder"
        ]
        let tiff: [CFString: Any] = [
            kCGImagePropertyTIFFMake: "Example Camera Company",
            kCGImagePropertyTIFFModel: "Prototype 42",
            kCGImagePropertyTIFFArtist: "Sample Photographer"
        ]
        let gps: [CFString: Any] = [
            kCGImagePropertyGPSLatitude: 40.015,
            kCGImagePropertyGPSLatitudeRef: "N",
            kCGImagePropertyGPSLongitude: 105.2705,
            kCGImagePropertyGPSLongitudeRef: "W"
        ]
        let properties: [CFString: Any] = [
            kCGImagePropertyOrientation: orientation,
            kCGImagePropertyExifDictionary: exif,
            kCGImagePropertyTIFFDictionary: tiff,
            kCGImagePropertyGPSDictionary: gps
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw FixtureError.encodingFailed
        }
        return data as Data
    }

    enum FixtureError: Error {
        case encodingFailed
    }
}
