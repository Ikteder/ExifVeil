# Synthetic metadata fixture card

Date created: 2026-09-14
License: MIT with the repository
External source: None

## Purpose

The XCTest suite generates a 2 by 3 pixel JPEG in memory to exercise the metadata pipeline without distributing a real person's photo or location history.

## Contents

- Solid authored blue pixels
- Synthetic GPS latitude and longitude near Boulder, Colorado
- Synthetic capture timestamp `2026:09:14 10:00:00`
- Fictional camera make `Example Camera Company`
- Fictional model `Prototype 42`
- Fictional artist `Sample Photographer`
- Synthetic user comment `Back door entry code reminder`
- Optional EXIF orientation value `6` for rotation verification

## Expected use

The fixture is created during tests, inspected, sanitized, and inspected again. It tests classifier categories, GPS display redaction, score bounds, output metadata removal, and orientation-normalized dimensions.

## Quality and limitations

- It is intentionally tiny and not representative of photo quality, camera codecs, color spaces, or malformed vendor metadata.
- It covers known dictionary keys only.
- It contains no third-party or personal data.
- Results on this fixture must not be generalized to every camera or sharing service.

