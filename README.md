# Joycon Mapper

A macOS utility for using a Nintendo Switch Joy-Con (L) as a small pointer and shortcut controller.

## Features

- Move the pointer with the left stick
- Tune pointer speed, deadzone, acceleration, and vertical direction
- Map Joy-Con buttons and D-pad inputs per profile
- Record custom keyboard shortcuts
- Hold modifier keys such as Command, Option, Shift, or Option + Command
- Assign mouse clicks, navigation keys, and custom actions
- Japanese and English UI

## Requirements

- macOS
- Nintendo Switch Joy-Con (L) connected over Bluetooth
- Accessibility permission for pointer movement and keyboard events

## Notes

Joy-Con controllers do not expose a microphone to macOS. This app can control microphone-related shortcuts such as mute or push-to-talk, but it cannot use a Joy-Con as an audio input device.

If macOS turns on Gaming Focus when the Joy-Con is connected, check System Settings > Focus > Gaming and disable automatic activation for wireless controllers. The app declares itself as a Utilities app, but the controller connection itself can still trigger macOS Focus automation.

## Development

Open `JoyconMapper.xcodeproj` in Xcode and run the `JoyconMapper` scheme.

Command-line build:

```sh
DEVELOPER_DIR=/Applications/Xcode-26.5.0-Beta.3.app/Contents/Developer \
xcodebuild -project JoyconMapper.xcodeproj \
  -scheme JoyconMapper \
  -configuration Debug \
  -derivedDataPath .build/xcode \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Distribution

The simplest download flow is:

1. Build a Release app.
2. Zip `JoyconMapper.app`.
3. Attach the zip to a GitHub Release.

For public distribution, the recommended flow is Developer ID signing plus notarization, then attaching a signed `.dmg` or `.zip` to a GitHub Release. Unsigned builds are fine for personal testing, but other users will see Gatekeeper warnings.

See [DISTRIBUTION.md](DISTRIBUTION.md) for the release script and Homebrew Cask template.
