# WaterSipAI (DrinkWater)

An iOS app that, at times you choose, locks you out until the front camera sees you drinking water.

**Privacy is the core promise. Keep it true in every change:** on-device AI (Apple's local Vision models), works offline, nothing is recorded (no photos or video saved or sent), and no data leaves the phone (no server, account, ads or tracking). The wording lives in `DrinkWater/Views/PrivacyPromise.swift`, `docs/privacy.html` and `appstore/listing.md`.

There are two builds from the same code:

| | Free build (`project-free.yml`) | Full build (`project.yml`) |
|---|---|---|
| Apple account | Free Apple ID | Paid Apple Developer account ($99/year) |
| Install | Cable from a Mac with Xcode | Cable from Xcode, TestFlight or App Store |
| Reminder notifications | Yes | Yes |
| Full-screen camera check in DrinkWater | Yes | Yes |
| Blocks your other apps | No | Yes, via Screen Time |
| Keeps working | 7 days, then plug in and press Run again | 1 year (cable) or indefinitely (App Store) |

## Quick start: free build over a cable

You need a Mac with Xcode 15 or later, your iPhone on iOS 17 or later, and its cable. Windows can't install iPhone apps.

1. On the Mac: `brew install xcodegen`, then in this folder run `xcodegen --spec project-free.yml`.
2. Open `DrinkWaterFree.xcodeproj`. In Xcode, go to Settings → Accounts and sign in with your normal Apple ID.
3. Select the DrinkWater target → Signing & Capabilities. Pick your "(Personal Team)" and change the bundle id `com.yourname.drinkwater` to something unique.
4. Plug in the iPhone and unlock it. Choose it as the run destination and press Run (⌘R).
5. The first time, iOS blocks the app. On the iPhone, go to Settings → General → VPN & Device Management, tap your Apple ID and choose Trust. If iOS asks, also turn on Settings → Privacy & Security → Developer Mode and restart.
6. Open DrinkWater, allow notifications, and set your schedule. Use **Lock now** to try the camera check.

In the free build, a reminder notification arrives at each time. Whenever you open DrinkWater after a reminder you haven't drunk for, the camera check covers the app until you drink. Other apps still work.

The free install stops opening after 7 days. Plug in and press Run again to renew it; your settings are kept.

## How the full build works

| Piece | What it does |
|---|---|
| `DrinkWater/` (app) | Setup screens, schedule, and the full-screen camera check |
| `DrinkWaterMonitor/` | Screen Time extension iOS wakes at each reminder time, even when the app is closed. It shields all apps and posts a notification. |
| `DrinkWaterShieldConfig/` | The "Drink some water first" screen shown over any blocked app |
| `DrinkWaterShieldAction/` | The shield's "Open DrinkWater" button (posts a notification you tap, since shields can't open apps) |
| `Shared/` | State shared through an App Group, plus lock/unlock code |

### Why it isn't a literal "take over the whole phone"

iOS doesn't let a normal app lock the device or stay on screen. The closest real thing is Apple's Screen Time API (FamilyControls, ManagedSettings, DeviceActivity): it puts a shield over every app except the ones you allow, and only this app can lift it. Home screen, Control Center, calls and Settings still work. Inside DrinkWater, the check is a full-screen cover that can't be swiped away.

### How drinking is detected

`DrinkWater/Detection/` uses Apple's built-in Vision models, so there is no model file to ship. All three of these must be in view:

1. **Face:** face landmarks find your mouth (falling back to the lower face when a cup hides your lips).
2. **Hand:** any part of a hand. A few fingers on a mug handle are enough.
3. **Cup at the face:** the built-in image classifier runs on the area around your face and hand and must see a container (bottle, cup, mug, glass, or a steel, metal or plastic cup) in at least 2 frames. A glass sitting on the desk doesn't count.

Once all three hold, progress builds; it unlocks after about 1.5 seconds of sipping (tilting your head back counts extra). Tunables are at the top of `DrinkCheck.swift` and `VisionSignalExtractor.swift`.

**See what it sees:** turn on Settings → Show detection details, or triple-tap the camera screen. It shows which of the three checks pass and the top labels the classifier sees around your mouth, which helps when tuning.

**Learning from feedback (on the phone only):** after a pass the check asks "Did you just drink?" (👍/👎), and after 15 seconds of trying it offers "I did drink, it didn't notice". Each answer saves the labels seen near the mouth and their confidences (no images) and tunes a per-user `DetectionProfile`: a label seen in 2 missed drinks becomes "your cup", a near-miss lowers the confidence bar (down to 10%), and a 👎 raises it and blocks learned labels that caused it. Body labels like "person" or "hand" are never learned. "I did drink" never logs a glass by itself; it only learns and lets you try again. See `DetectionProfile.swift`; Settings → Drink check learning shows what was learned and can reset it.

**Next step for accuracy:** record 30 to 50 short clips of yourself drinking and not drinking, train an Action Classifier in Create ML (it uses body pose), and add it as another `SignalExtractor`.

### Today and Stats

- **Today** shows how many glasses you've had today, with an **Add a glass** button. It opens the camera, and when it sees you drink it logs a glass with the time.
- **Stats** has a 7- or 30-day chart of glasses (and misses) per day, your average, and every entry with its timestamp, grouped by day. Swipe left on an entry in Today to delete it.
- Tapping **Skip for now** on a reminder logs a missed glass.

### Reminders in the free build

iOS never lets an app open itself, so a notification is the strongest nudge available. At each reminder time you get a notification, then a follow-up every 5 minutes (up to 4) until you drink or skip. Tapping any of them opens DrinkWater straight into the camera check. Opening DrinkWater after a missed reminder also lands on the check.

**Vibration and sound** (Settings → Reminder alerts): vibration is on and sound is off by default. You can pick Water drop, Chime, Bell or the iPhone default sound. With the app open, a reminder vibrates 3 times. A notification that arrives in the background vibrates once, because iOS doesn't let apps choose a vibration pattern for notifications. Sound files live in `DrinkWater/Sounds/`; any `.wav` under 30 seconds can be added there and listed in `AlertSettings.Sound`.

Notifications are planned for the next day or two and re-planned each time you open the app, so open it at least once a day.

### Escape hatch

`Shared/FeatureFlags.swift` → `escapeHatchEnabled = true` shows a "Skip for now" button. Set it to `false` to remove it. Even then, iOS always lets you turn off Screen Time access for the app in Settings; no app can block that.

## Full build (paid account)

You need a Mac with Xcode 15+, an iPhone on iOS 17+, and an Apple Developer account. Screen Time features and the camera don't work in the Simulator.

1. `brew install xcodegen`, then run `xcodegen` in this folder to create `DrinkWater.xcodeproj`. This build compiles with the `SCREEN_TIME` flag.
2. Open it, set your Team on all four targets, and change `com.example` to your own bundle id prefix. If you do, also update the App Group id in `Shared/SharedStore.swift` and in `project.yml`.
3. In Signing & Capabilities, confirm **Family Controls** and **App Groups** are on for every target.
4. Run on your iPhone. Allow Screen Time and notifications.
5. Tap **Choose always-allowed apps** and pick DrinkWater itself (plus Phone and anything else you never want blocked).
6. Set the schedule and tap **Save schedule**. Use **Lock now** to test without waiting.

### Family Controls entitlement

The development version of the entitlement works on your own phone straight from Xcode. To ship through TestFlight or the App Store, request the distribution entitlement from Apple at https://developer.apple.com/contact/request/family-controls-distribution (one request per bundle id, including each extension).

## Limits to know

- Up to 20 reminders a day (iOS caps how many schedules an app can watch). Each is at least 15 minutes apart.
- iOS decides exactly when the monitor extension runs; it's usually on time but can be a little late.
- This code was written without a Mac to compile on, so expect a few small fixes the first time you build.

## Releasing to the App Store

Version 1 ships from `project-free.yml` (no Screen Time). You need a paid Apple Developer account.

1. Make sure `PRODUCT_BUNDLE_IDENTIFIER` in `project-free.yml` is the id you want forever (it's `com.mangaldev.drinkwater`). Run `xcodegen --spec project-free.yml`.
2. In Xcode, pick your paid team under Signing & Capabilities.
3. Create the app in [App Store Connect](https://appstoreconnect.apple.com) → Apps → + → New App, with the same bundle id. Fill it in from [`appstore/listing.md`](appstore/listing.md).
4. Turn on GitHub Pages for this repo (Settings → Pages → Deploy from a branch → `main`, folder `/docs`), so the privacy and support links work.
5. In Xcode, choose **Any iOS Device (arm64)** as the destination, then Product → Archive → Distribute App → App Store Connect → Upload.
6. In App Store Connect, select the uploaded build, add screenshots, answer App Privacy with "Data Not Collected", paste the review notes, and Submit for Review.
7. For every later upload, raise `CURRENT_PROJECT_VERSION` (and `MARKETING_VERSION` for a new version) in `project-free.yml`.

Release builds hide the testing tools ("Lock now" and the detection overlay). They only appear when you run from Xcode in Debug.
