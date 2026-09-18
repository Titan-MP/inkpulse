# Inkpulse — a blue-ringed octopus arcade

You are a blue-ringed octopus drifting through an endless reef. Drag to steer,
tap to flash your venom rings and stun predators, eat shrimp to fill your ink
meter, double-tap to ink-dash. Three hits and the run is over.

**The hooks that make it replayable:** perfect-timed stuns with combo
multipliers, near-miss bonuses, a seeded Daily Reef everyone plays together,
Game Center leaderboards, unlockable color-morph skins, daily streaks, and
haptics on everything that matters.

## Monetization (all wired up)

| Stream | How |
|---|---|
| Rewarded ads | Revive a run, or double shells after a run. Only ever opt-in. |
| Remove Ads | $4.99 non-consumable |
| Skin packs | Kelp Ghost + Coral Dawn, $1.99 each (also earnable skins via shells) |
| Shell packs | Consumable 600 / 1,600 / 4,000 |

No loot boxes, no pay-to-win, no interstitials. Product IDs live in
`BlueRing/Services/StoreService.swift` and must match App Store Connect.

## Run it in Xcode

1. Open `BlueRing.xcodeproj` (Xcode 16+, iOS 17+).
2. Select the BlueRing target → Signing & Capabilities → set your **Team**.
3. Enable the **Game Center** capability if Xcode doesn't pick it up from the entitlements file.
4. To test purchases: Scheme → Edit Scheme → Run → Options → StoreKit Configuration → choose `BlueRing.storekit`.
5. Build & run on a device (haptics don't work in the simulator).

### Ads (optional)
`AdsService` compiles with or without the Google Mobile Ads SDK thanks to
`#if canImport`. To enable real rewarded ads: in Xcode,
File → Add Package Dependencies → `https://github.com/googleads/swift-package-manager-google-mobile-ads`,
then replace the test ad unit ID in `AdsService.swift` with your own and add
your AdMob app ID to the Info plist (`GADApplicationIdentifier`).

## Ship it: GitHub → TestFlight

Pushing to `main` runs `.github/workflows/testflight.yml`, which builds and
uploads to TestFlight via fastlane. Add these repo secrets first
(Settings → Secrets and variables → Actions):

| Secret | Where to get it |
|---|---|
| `ASC_KEY_ID` | App Store Connect → Users and Access → Integrations → App Store Connect API |
| `ASC_ISSUER_ID` | Same page (Issuer ID) |
| `ASC_KEY_P8` | The `.p8` key file, base64-encoded |
| `APPLE_ID` | Your Apple ID email |
| `TEAM_ID` | Developer portal → Membership (10-char team ID) |

The API key needs **App Manager** access or higher.

## App Store submission checklist

- [ ] Create the app record in App Store Connect (bundle ID `com.rhymaun.bluering`)
- [ ] Create the 6 in-app purchase products with the exact IDs in `StoreIDs`
- [ ] Create leaderboards `reef_best` and `reef_daily`
- [ ] Screenshots (6.7" + 6.5" + iPad), description, keywords, support URL
- [ ] Privacy policy URL (you have one at rhymaun.com/privacy — extend it for the game)
- [ ] Age rating questionnaire, export compliance (no encryption beyond HTTPS → exempt)
- [ ] Submit for review from the TestFlight build

## Project layout

```
BlueRing/
  BlueRingApp.swift          App entry, service wiring
  ContentView.swift          Menu, HUD, shop, game-over, how-to
  Game/
    GameScene.swift          Gameplay: spawning, pulse, dash, scoring
    OctopusNode.swift        Procedural octopus (body, arms, glowing rings)
    Predators.swift          Eel, lionfish, puffer + prey
  Services/
    GameState.swift          Score, shells, skins, streaks (UserDefaults)
    StoreService.swift       StoreKit 2 purchases
    AdsService.swift         Rewarded ads (AdMob, optional)
    GameCenterService.swift  Auth + leaderboards
  BlueRing.storekit          Local test products
  Assets.xcassets            App icon
fastlane/                    TestFlight lane
.github/workflows/           CI
```
