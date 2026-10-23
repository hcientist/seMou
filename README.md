# Semou

A menu bar app for macOS 13 and later that makes multi-monitor setups easier to move around.

- **Edge wrap:** push the cursor past the right edge of the right-most display and it comes out at the left edge of the left-most display, and the other way round. It stays at the same height, or the same relative height when the displays differ in size.
- **Jump to display:** press ⌃⌥⌘ and an arrow key to move the cursor to the center of the next display in that direction. At the end of a row or column it wraps around.
- **Pie menu:** press ⌃⌥⌘Space to open a radial menu at the cursor. Then flick the mouse toward a wedge, click a wedge, or press an arrow key. Esc or a click anywhere else closes it.

The menu bar icon has toggles for edge wrap, wrapping while dragging, and launch at login.

It needs no special permissions. Mouse movement is watched with an `NSEvent` global monitor, hotkeys use Carbon `RegisterEventHotKey`, and the cursor is moved with `CGWarpMouseCursorPosition`.

## Build

`Semou.xcodeproj` is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen). After adding files or changing settings, run `xcodegen generate`. Then open the project in Xcode and press Run.

The app is sandboxed (`Resources/Semou.entitlements`), which TestFlight and the Mac App Store require.

## TestFlight

1. In App Store Connect, create a macOS app with the bundle ID `com.hcientist.semou`.
2. Run `./release.sh`. It archives the app and uploads it with `ExportOptions.plist`. Build numbers go up automatically.
3. Once the build has finished processing, add testers in App Store Connect → TestFlight.

You can also go through Xcode: Product → Archive, then Distribute App → TestFlight & App Store.

## Continuous delivery

`.github/workflows/testflight.yml` archives the app and uploads it to TestFlight on every push to `main` that changes more than Markdown files. You can also start it by hand from the Actions tab. The build number is the workflow run number.

Signing is cloud-managed through an App Store Connect API key, so no certificates are stored in the repo. Create a key under App Store Connect → Users and Access → Integrations → Team Keys, with the **Admin** role so it can use cloud-managed distribution signing. Then add these repository secrets:

| Secret | Value |
| --- | --- |
| `ASC_KEY_ID` | The key's ID |
| `ASC_ISSUER_ID` | The Issuer ID shown above the key list |
| `ASC_KEY_P8` | The full contents of the downloaded `AuthKey_XXXX.p8` |
