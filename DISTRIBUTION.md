# Distribution

## Recommendation

Use GitHub Releases first, then add a Homebrew Cask once the release artifact is signed and notarized.

The Mac App Store is not the best first target for this app. Joycon Mapper needs HID access, Accessibility permission, pointer movement, and synthetic keyboard events. Those features are useful for a local utility, but they are a poor fit for Mac App Store sandboxing and review. The app currently disables App Sandbox for that reason.

## Release Channels

### GitHub Releases

Best first step.

- Lowest maintenance
- Works with signed and notarized `.zip` or `.dmg`
- Easy to attach release notes
- Required anyway if you want a Homebrew Cask

### Homebrew Cask

Best second step.

Homebrew Cask should point at the GitHub Release artifact. It does not replace signing or notarization; users still benefit from a Developer ID signed and notarized app.

Recommended flow:

1. Create a GitHub Release such as `v0.1.0`.
2. Attach `JoyconMapper-v0.1.0.zip`.
3. Compute its SHA-256.
4. Update a Cask formula with the release URL and SHA-256.
5. Publish the Cask in a tap, for example `naoki-mrmt/homebrew-tap`.

### Mac App Store

Consider later only if you want broad consumer distribution and are willing to redesign around sandbox constraints.

Likely blockers:

- App Sandbox is currently disabled.
- The app posts keyboard and mouse events.
- The app depends on Accessibility permission.
- Joy-Con HID input and system-level control may invite review questions.

## Signing And Notarization

For distribution outside the Mac App Store, the ideal artifact is:

- Signed with a Developer ID Application certificate
- Hardened Runtime enabled
- Submitted to Apple notarization
- Stapled before zipping or packaging

Check prerequisites:

```sh
./scripts/check-distribution-prereqs.sh
```

Create a notary profile once:

```sh
xcrun notarytool store-credentials joycon-mapper-notary
```

You also need a `Developer ID Application` certificate installed in Keychain Access. An `Apple Development` certificate is enough for local development, but not for public notarized distribution.

Then package:

```sh
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="joycon-mapper-notary" \
./scripts/package-release.sh 0.1.0
```

For local testing without signing:

```sh
./scripts/package-release.sh 0.1.0
```

Unsigned builds are useful for development, but other users will see Gatekeeper friction.

## Homebrew Cask Template

See `packaging/homebrew/joycon-mapper.rb`.

For a personal tap, create `naoki-mrmt/homebrew-tap`, then put the Cask at:

```text
Casks/joycon-mapper.rb
```

Users would install it with:

```sh
brew tap naoki-mrmt/tap
brew install --cask joycon-mapper
```
