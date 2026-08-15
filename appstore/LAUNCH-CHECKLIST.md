# Launch Checklist — Tonestep

Split by who can actually do each item. Everything under "Done" is verified, not
assumed; the evidence is named so you can re-check it yourself.

## Done and verified

- [x] **App runs full-screen.** `UILaunchScreen` present — without it iOS
      letterboxes the app into a 320×480 canvas with black bars. Guarded by
      `InfoPlistTests`.
- [x] **Singing Practice no longer crashes.** `NSMicrophoneUsageDescription` was
      being silently dropped (declared as `INFOPLIST_KEY_*` against an explicit
      Info.plist, which Xcode only merges when `GENERATE_INFOPLIST_FILE` is YES).
      Verified present in the built bundle; guarded by a test.
- [x] **Export compliance answered in the plist.** `ITSAppUsesNonExemptEncryption`
      is `false`, so App Store Connect stops asking on every upload.
- [x] **Privacy policy URL loads.** Returns HTTP 200 at
      https://yuganshjain.github.io/Tonestep/privacy.html and is branded Tonestep.
      Review rejects a privacy URL that fails to load.
- [x] **Privacy manifest present** (`PrivacyInfo.xcprivacy`) with the UserDefaults
      required-reason API declared (CA92.1). See the open question below.
- [x] **App icon** — 1024×1024, no alpha, no baked corner radius, no text.
- [x] **Bundle IDs final** — `com.yugansh.Tonestep`, chosen before submission
      because the bundle ID is permanent once the app exists in App Store Connect.
- [x] **Curriculum works end to end** — stage completes, scores, persists, unlocks
      the next stage. Driven by hand in the Simulator, not just unit-tested.
- [x] **181 tests passing.**
- [x] **Singing Practice fixed and verified live.** It had *two* stacked crashes:
      the missing Info.plist key, and then an AVAudioSession bug — the session is
      configured `.playback`, which forbids recording, so the input node reported
      a zero format and `installTapOnBus` raised an uncatchable ObjC exception.
      Now switches to `.playAndRecord` before capture, validates the format, and
      restores `.playback` on stop. Confirmed live: mic captures, pitch tracks,
      meter responds, no crash logged.
- [x] **Chord Progressions verified after refactor** — converting it to a
      spec-driven renderer did not regress standalone practice (answer scored,
      +15 XP awarded).
- [x] **DEBUG-only Pro unlock** (`TONESTEP_FORCE_PRO` env var) for exercising
      Pro screens in the Simulator. Proven absent from the Release binary.
- [x] **Screenshots** at 1320×2868 (6.9", the size Apple requires).
- [x] **Listing copy drafted** — `appstore/LISTING.md`.

## Module verification status

**All 15 modules verified by hand in the Simulator. Zero crashes.**

| Module | Verified |
|---|---|
| Interval Recognition | via a full curriculum stage |
| Chord Recognition | via a full curriculum stage |
| Scale Recognition | via a full curriculum stage |
| Functional Ear | full stage: 10 questions, 100%, 3 stars, stage 2 unlocked |
| Chord Progressions | opened, answered, +15 XP — no regression from the refactor |
| Rhythm Trainer | opened, pattern rendered, four options |
| Melodic Dictation | opened, piano input and Undo/Check present |
| Relative Pitch | opened, cadence-primed, eight degree options |
| Absolute Pitch | opened, Natural/Chromatic difficulty toggle works |
| Singing Practice | **fixed twice**, then verified live: mic captures, pitch tracks |
| Note Identification | opened, 12 chromatic options |
| Chord Inversions | opened, figured-bass notation renders |
| Interval Comparison | opened, A/B playback and three options |
| Error Detection | opened, four beats, playback control |
| Jazz Chords | opened, answered, correct/wrong highlighting, score updated |
| Speed Round | opened, 60s timer counting down, progress bar draining |

Method: launched with the DEBUG unlock, opened every module, confirmed it
renders and accepts input, and compared crash-report counts before and after.
The count did not move.

Not covered by this sweep: whether the *audio* sounds right (needs ears), and
MIDI hardware (needs a keyboard).

## Only you can do these

- [ ] **Create the IAP products in App Store Connect** with these exact IDs:
      - `com.yugansh.Tonestep.pro.monthly`
      - `com.yugansh.Tonestep.pro.annual`
      - `com.yugansh.Tonestep.pro.lifetime`
      They must match `Tonestep/Tonestep.storekit`. Prices in that file are
      placeholders for Simulator testing only — real prices are set in App Store
      Connect and have not been decided.
- [x] **Installed on a physical iPhone.** Confirmed present on Yugansh's
      iPhone 17 Pro as `com.yugansh.Tonestep` 1.0 (1). This was blocked for the
      whole project by a wrong `DEVELOPMENT_TEAM` in project.yml — it named a
      team with no account on this Mac, so signing always failed. Corrected to
      X8TTT9UQMY, the team owning all 22 installed profiles.
      Reinstall after changes:
      `xcodebuild -scheme Tonestep -destination 'generic/platform=iOS' -configuration Debug -derivedDataPath /tmp/tonestep-device -allowProvisioningUpdates build`
      then
      `xcrun devicectl device install app --device 4C829A32-EEA6-50E4-B8E5-8853EAB981C9 /tmp/tonestep-device/Build/Products/Debug-iphoneos/Tonestep.app`
- [ ] **First launch on device**: unlock the phone and tap the icon (iOS refuses
      remote launches while locked). If iOS blocks it as an untrusted developer,
      Settings → General → VPN & Device Management → trust the certificate.
- [ ] **Test MIDI with a real keyboard.** `MIDIInputSource` compiles and is
      deliberately logic-free, but its packet parsing has never met hardware.
      The Simulator has no MIDI at all.
- [ ] **Listen to the synthesised instruments.** Tests prove piano and violin
      produce different waveforms with the right envelopes. They cannot prove a
      piano sounds like a piano. If one is wrong, the fix is localised to
      `InstrumentVoice.voice(for:)`.
- [ ] **Trademark check on "Tonestep".** No App Store conflict found via Apple's
      search API, and no company surfaced in search — but the registry lookups
      never returned, so this is genuinely unverified. It is the one remaining
      risk that can pull a listing after you have built up ranking.
- [ ] **Retake the Today and Progress screenshots** after a few days of real use.
      They currently show zeros.
- [ ] **Fill in App Store Connect**: age rating (4+), category (Education, or
      Music as secondary), support URL, privacy answers, and the copy from
      `LISTING.md`.

## Open question worth deciding before you submit

**The privacy manifest over-declares.** `PrivacyInfo.xcprivacy` lists
`NSPrivacyCollectedDataTypeAudioData` as collected. Apple defines "collect" as
transmitting data off the device — and Tonestep analyses microphone audio live on
device and never records, stores or uploads it. Your own privacy policy says
exactly that.

Declaring it anyway produces an App Store privacy label reading "Audio Data
collected", which is both inaccurate and actively harmful to conversion for an app
whose real story is "nothing leaves your phone".

I have **not** changed it, because a privacy declaration is a compliance statement
that should be yours to make. My reading is that `AudioData` should be removed.
`OtherUserContent` is more arguable — Game Center leaderboard submissions do send
scores to Apple, so that one may be justified.

## Known gaps that are not launch blockers

- Play-Along ships with three public-domain pieces and a piano-only keyboard.
  Enough to prove the mechanic; not a content library. Song licensing remains
  unsolved and is the largest business risk in the instrument-learning direction.
- The curriculum covers 5 of the 15 modules. The other ten work as standalone
  practice and feed spaced repetition, but do not yet appear in graded stages.
  Each needs converting to a spec-driven renderer first — that is engineering
  work, not data entry.
- Free tier is 70 of 112 stages (63%). Generous by design, to avoid a paywall
  mid-arc. If conversion is weak, moving the boundary earlier is a one-line
  change to `isProOnly` in `CurriculumBuilder`.
