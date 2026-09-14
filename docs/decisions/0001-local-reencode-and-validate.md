# Decision 0001: Re-encode a new copy and validate the postcondition

Date: 2026-09-14
Status: Accepted

## Context

Copying an image source while selectively deleting metadata is fragile because nested vendor namespaces can survive. Removing only the keys shown in the report would also make the output guarantee depend entirely on classifier completeness. The original must remain untouched.

## Decision

ExifVeil decodes one still frame, applies its EXIF orientation to pixels, and creates a new JPEG or PNG without copying the source metadata dictionary. It then runs the same sensitive-key inspector over the output. A non-empty finding list blocks sharing.

JPEG output uses quality `0.92`. PNG input remains PNG. Other supported still-image inputs become JPEG. Multi-frame inputs are rejected in version 1.0.

## Consequences

- The original file is never modified.
- Known sensitive metadata is checked as an explicit postcondition.
- Orientation remains visually correct after its metadata tag is removed.
- JPEG bytes, file size, and some pixel values may change.
- Unknown metadata might not be classified, although omitting the entire source metadata dictionary reduces that risk.
- Codec and color-profile behavior need a broader future corpus.

