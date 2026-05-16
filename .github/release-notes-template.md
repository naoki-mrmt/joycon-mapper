# Joycon Mapper vX.Y.Z

Signed and notarized macOS build.

## Highlights

- 

## Verification

- Unit tests: `./scripts/ci-check.sh`
- Release verification: `./scripts/verify-release.sh X.Y.Z`
- Gatekeeper: accepted as Notarized Developer ID

## Install

```sh
brew update
brew upgrade --cask joycon-mapper
```

New install:

```sh
brew tap naoki-mrmt/tap
brew install --cask joycon-mapper
```

## Known Limits

- Joy-Con does not provide a macOS microphone input.
- Joy-Con (R) is not supported yet.
- Mac App Store distribution is not supported.
