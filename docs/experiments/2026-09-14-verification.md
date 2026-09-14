# Verification record: 2026-09-14

## Environment boundary

- Authoring host: Windows, no Swift or Xcode installed
- Local checks: passed on Node.js 26.8.1 and PowerShell
- Native package tests: 6/6 passed in hosted macOS CI
- iOS Simulator compile/tests: app built and 6/6 passed in hosted CI
- Physical iPhone/iPad: not tested

## Planned assertions

1. The synthetic fixture surfaces all five supported categories.
2. Exact GPS values are not displayed in findings.
3. The privacy signal is bounded at 100.
4. Invalid image bytes produce typed errors.
5. Re-encoding leaves zero known sensitive findings.
6. EXIF orientation `6` swaps the generated 2 by 3 image to 3 by 2 pixels and is absent from the output metadata.
7. The iOS app target compiles and its XCTest bundle passes on an available hosted simulator.
8. Static checks find no network API, broad Photos authorization, README em dash, or missing repository visual.

## Local results

Commands:

```text
node tests/static-check.mjs
git diff --check
PowerShell XML parse of docs/assets/privacy-pipeline.svg
PowerShell README em dash scan
```

Results:

- Static verifier: 8 checks passed across 5 Swift source files.
- Privacy boundary: no `URLSession`, Network framework import, `NWConnection`, or broad `PHPhotoLibrary.requestAuthorization` call found.
- README em dash count: 0 across both repository README files.
- SVG: valid XML.
- Git whitespace check: passed.

## Hosted results

GitHub Actions run: `34891290417`

- Runner: macOS 15.7.9 arm64 with Xcode 16.4 and iPhone Simulator SDK 18.5.
- Swift package: build passed; 6 tests executed with 0 failures in 0.309 seconds.
- XcodeGen: installation and `xcodegen generate` passed.
- iOS target: `xcodebuild test` compiled the SwiftUI app and test bundle for the first available iPhone simulator.
- iOS Simulator: 6 tests executed with 0 failures in 0.847 seconds; `TEST SUCCEEDED`.
- Windows static job: 8 repository and privacy checks passed.
- Public README visual: raw SVG returned HTTP 200 with content type `image/svg+xml`.

The fixture test confirmed all five supported metadata categories, hidden GPS display values, a bounded 100 signal, typed malformed-input handling, zero known sensitive findings after sanitation, and a 3 by 2 output after normalizing orientation `6` from a 2 by 3 source.

## Corrections made during CI

1. Run `34867591895` exposed a Swift parser limitation for a `switch` expression inside addition. The reducer now assigns an explicit local weight.
2. Run `34867761408` showed that ImageIO can create a zero-frame source for arbitrary bytes. Both APIs now classify zero frames as invalid data rather than an animated image.
3. Run `34890775795` passed the package suite and app compilation but exposed an app/module-name difference in the shared XCTest file. A conditional import now runs the same suite as `ExifVeilCore` under Swift Package Manager and `ExifVeil` under Xcode.

These fixes preserved the intended privacy behavior and were verified by the passing replacement run.
