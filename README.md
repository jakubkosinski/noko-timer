# NokoBar

macOS menu bar client for [Noko](https://nokotime.com) (API v2): start, pause, resume and finish timers.

## Build
```
brew install xcodegen
xcodegen generate
open NokoBar.xcodeproj      # or: xcodebuild -scheme NokoBar -destination 'platform=macOS' build test
```
Requires macOS 14+. Log in with a Personal Access Token (stored in the Keychain).

## Launch at login
Enable it in Preferences. For it to keep working, run the app from `/Applications` (the login item points to the app's current location).
