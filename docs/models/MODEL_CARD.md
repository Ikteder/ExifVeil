# Model non-use card

Date: 2026-09-14

ExifVeil does not train, download, embed, or call a machine-learning model. It uses deterministic ImageIO metadata extraction, an explicit key classifier, Core Image orientation transforms, and ImageIO encoding.

## Intended interpretation

The displayed privacy signal is a transparent weighted sum over visible findings. It is not learned, calibrated against a population, or a probability of harm.

## Non-goals and risks

- No face, text, object, scene, or steganography analysis is performed on pixels.
- No claim is made that a zero-finding image is anonymous or safe to publish.
- Unknown vendor keys can fall outside the explicit classifier.
- Location fields receive the highest weight, but weights remain product choices rather than empirical risk estimates.

