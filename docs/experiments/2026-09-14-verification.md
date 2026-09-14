# Verification record: 2026-09-14

## Environment boundary

- Authoring host: Windows, no Swift or Xcode installed
- Local checks: passed on Node.js 26.8.1 and PowerShell
- Native package tests: pending hosted macOS CI
- iOS Simulator compile/tests: pending hosted macOS CI
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

Hosted Swift and simulator results remain pending until the repository is published.
