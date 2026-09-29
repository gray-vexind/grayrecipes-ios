# Gray Recipes — iOS

A native SwiftUI app for [grayrecipes.com](https://grayrecipes.com). Scan recipes
from cookbooks and cards with **live document capture**, extract the text
(on-device Vision OCR for instant feedback, then AWS Textract on the server for
accuracy), review, and save straight into your Gray Recipes group.

## Features

- **Live capture** — VisionKit document scanner with automatic edge detection and
  perspective correction.
- **Instant on-device OCR** — Apple's Vision framework reads the text immediately,
  so the review form is pre-filled before the network call finishes.
- **Server extraction** — the captured page is sent to `POST /api/extract`
  (AWS Textract) and merged in for higher accuracy.
- **Review & edit** — fix the title, ingredients (reorderable), steps, times, and
  author before saving.
- **Save to a group** — writes to `POST /api/recipes` for the selected tenant.
- **Bearer-token auth** — logs in via `POST /api/auth/mobile`, stores tokens in the
  Keychain, and refreshes transparently via `POST /api/auth/mobile/refresh`.

## Requirements

- macOS with **Xcode 15+**
- iOS **17.0+** device (the document scanner needs a real camera; the Simulator
  cannot scan, though you can still browse recipes and log in)
- An Apple Developer team for signing (free personal team is fine for device testing)

## Getting started

The project is defined with [XcodeGen](https://github.com/yonatanb/XcodeGen) so the
`.xcodeproj` isn't committed (avoids merge conflicts). Two options:

### Option A — XcodeGen (recommended)

```bash
brew install xcodegen        # if you don't have it
cd grayrecipes-ios
xcodegen generate            # creates GrayRecipes.xcodeproj
open GrayRecipes.xcodeproj
```

### Option B — Manual Xcode project

1. In Xcode: **File ▸ New ▸ Project… ▸ iOS ▸ App**, name it `GrayRecipes`,
   interface **SwiftUI**, language **Swift**.
2. Delete the auto-generated `ContentView.swift` / `App.swift`.
3. Drag the `GrayRecipes/` folder from this repo into the project (choose
   *Create groups*), and set `Info.plist` as the target's Info.plist.
4. Confirm the camera/photo usage keys exist in Info.plist (they're already in the
   provided one).

### Signing

Open the target's **Signing & Capabilities** tab and select your Team, or set
`DEVELOPMENT_TEAM` in `project.yml` before running `xcodegen generate`.

Then pick a physical device and press **Run** (⌘R).

## Configuration

All configuration lives in `GrayRecipes/App/AppConfig.swift`:

```swift
static let baseURL = URL(string: "https://grayrecipes.com")!
```

Point this at a staging/local server if needed. If you use a plain-HTTP dev server
you'll also need an App Transport Security exception in `Info.plist`.

## How it talks to the backend

| Action        | Endpoint                        | Auth        |
|---------------|---------------------------------|-------------|
| Login         | `POST /api/auth/mobile`         | none        |
| Refresh       | `POST /api/auth/mobile/refresh` | refresh JWT |
| Current user  | `GET /api/auth/mobile/me`       | Bearer      |
| List groups   | `GET /api/tenants`              | none        |
| List recipes  | `GET /api/recipes?tenant=slug`  | Bearer      |
| Recipe detail | `GET /api/recipes/:id`          | Bearer      |
| Extract text  | `POST /api/extract` (multipart) | none        |
| Create recipe | `POST /api/recipes` (multipart) | Bearer      |

These mobile auth endpoints were added to the `grayrecipes` backend. Tokens are
HS256 JWTs signed with the backend's `SESSION_SECRET`, consistent with the web
session. Access tokens last 1 hour; refresh tokens last 30 days.

> **Note on groups:** `GET /api/tenants` lists *public* groups. Saving requires
> membership with at least the `contributor` role in the chosen group; the server
> enforces this and the app surfaces a clear message if you lack permission.

## Project layout

```
GrayRecipes/
├── App/            App entry, config, session store
├── Models/         Codable models matching the API
├── Networking/     Keychain, APIClient (bearer + refresh), typed endpoints
├── Capture/        Document scanner, on-device OCR, capture pipeline + parser
└── Views/          Login, tabs, recipe list/detail, capture flow, review form
```

## Notes & next steps

- The app merges on-device OCR with server Textract; if the server call fails it
  falls back to the on-device result so capture still works offline-ish.
- A natural enhancement is a dedicated "my groups" endpoint so the group picker
  shows only groups the user can write to (today it lists public groups).
