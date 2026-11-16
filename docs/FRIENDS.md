# Putting Fitchi on a friend's iPhone

Friends get Fitchi through **TestFlight**: they tap an invite link, the app installs like any
other, updates arrive on their own, and each build lasts 90 days. No Apple Watch is needed.
With no watch paired, the iPhone becomes the pet's home: it gives them the starter egg, sends
care reminders, and earns Pep from steps.

## One-time setup (yours, in the browser)

1. **Create the app** in [App Store Connect](https://appstoreconnect.apple.com) › Apps › **+** ›
   New App: platform iOS, name "Fitchi" (if taken, any name; it's only shown in TestFlight for
   now), primary language, bundle ID `com.nicholasferreira.fitchi`, SKU `fitchi`, full access.
2. **Upload a build** from this Mac (no devices need to be connected):
   ```sh
   ./scripts/deploy.sh testflight
   ```
   Release build, so no developer tools and no free test Pep. It shows up under the app's
   **TestFlight** tab after Apple processes it (5–30 minutes).
3. **Make a tester group:** TestFlight tab › External Testing › **+** › a group called
   "Friends". Add the build to it and fill in the short "What to Test" note and beta review
   contact details. The first build for external testers goes through a quick Apple review
   (usually under a day); later builds mostly don't.
4. **Invite:** in the group, turn on **Public Link** and send that link to friends, or add their
   email addresses.

## What your friend does

1. Install **TestFlight** from the App Store.
2. Tap your link (or the email invite) › **Accept** › **Install**.
3. Open Fitchi and allow Health access when asked. Steps and workouts are how it earns, so at
   least Steps and Workouts are needed. Then walk to hatch the egg.

If they have an Apple Watch, the watch app usually installs with it. If not, they can install it
once from the Watch app on the iPhone (Available Apps › Fitchi › **Install**). After that, never
remove it from the watch: that deletes the watch's copy of the pet.

**Never delete the app.** Deleting it deletes the pet (without a watch there's no backup).
Updating from TestFlight keeps it. A friend who had the cable-installed version can install
the TestFlight one over the top.

## Sending an update

```sh
./scripts/deploy.sh testflight
```

Then in App Store Connect › TestFlight, add the new build to the Friends group. Friends see
the update in the TestFlight app (or automatically, if they turned on automatic updates).
Builds expire after 90 days, so upload at least that often.

## If something goes wrong

- **Upload fails with "No suitable application records were found":** the app doesn't exist
  in App Store Connect yet (setup step 1), or its bundle ID doesn't match.
- **Signing or account errors in `.build/testflight-*.log`:** open Xcode › Settings › Accounts,
  check you're signed in, select your team and click **Download Manual Profiles**, then retry.
- **"Missing Compliance" on a build:** shouldn't happen (`ITSAppUsesNonExemptEncryption` is
  NO); if it does, answer "None of the algorithms mentioned above".

## Backup: install with a cable

For quick tests on a phone that's here, without waiting for TestFlight:

1. Plug the iPhone into this Mac, unlock it and tap **Trust This Computer**.
2. On the phone, turn on Settings › Privacy & Security › **Developer Mode** and restart.
3. `./scripts/deploy.sh --devices` to find its name, then
   `./scripts/deploy.sh phone --device "Sam" --release`.

With the paid program, these installs last a year instead of 7 days.
