# MFT Hub

A personal food-logging iOS app. Log meals by **photo or plain text** and an AI backend
estimates the calories and macros — then track your day against a goal, see a 7-day trend,
log your weight, and glance at "calories left" from a Lock Screen / Home Screen widget.

The app is a thin SwiftUI client; all data and the AI key live on your own server
(see the companion backend), so nothing sensitive ships in the app.

## Features
- 📷 / ✍️ Log food by photo or text → AI calorie + macro estimate
- Daily calorie ring (calories left), protein / carbs / fat
- Day-by-day history with a 7-day calorie chart
- Weight logging with a trend line
- Routine "usual" foods for one-tap entry
- Edit / delete entries, undo, haptics, light & dark mode
- WidgetKit widget (Lock Screen + Home Screen)

## Setup
1. Open `MFT Hub.xcodeproj` in Xcode.
2. Create your secrets files (they're git-ignored) by copying `Secrets.example.swift` to **both**:
   - `MFT Hub/Secrets.swift`
   - `MFTWidget/Secrets.swift`
   …and fill in your server URL + access token.
3. Set your signing team, then build & run.

> The backend exposes `/estimate`, `/entries`, `/summary`, `/weights`, `/settings`, `/today`
> and authenticates with a shared bearer token (the `token` in `Secrets.swift`).

## Stack
SwiftUI · Swift Charts · WidgetKit · a small server (PHP/SQLite) that proxies the AI provider.
