# Putting Fitchi on a friend's iPhone

Without the paid Apple Developer Program there's no TestFlight, so a friend's iPhone gets the app
the same way yours does: plugged into this Mac, signed with your free Apple ID (Personal Team).
No Apple Watch is needed. With no watch paired, the iPhone becomes the pet's home: it gives them
the starter egg, sends care reminders, and earns Pep from steps (see `PointsRules.v3`).

## The catch: 7 days

Apps signed with a free Apple ID stop opening **7 days** after they're installed. To renew,
plug their phone in again and run the same install command. That reinstalls over the top
and **keeps their pet**. Tell your friend:

- **Never delete the app.** Deleting it deletes the pet (there's no watch backup for them).
- If it won't open ("no longer available"), bring the phone over for a reinstall.

## First time (about 10 minutes, phone in hand)

1. **Connect:** plug their iPhone into this Mac with a cable and unlock it. On the phone, tap
   **Trust This Computer** and enter the passcode.
2. **Turn on Developer Mode:** on the phone, go to Settings › Privacy & Security ›
   **Developer Mode**, switch it on, and restart when asked. After the restart, confirm
   **Turn On**. If the switch isn't there yet, open Xcode › Window › Devices and Simulators with
   the phone connected, and it will appear.
3. **Find its name:**
   ```sh
   ./scripts/deploy.sh --devices
   ```
   Their phone should be listed as `paired`. Part of the name is enough for the next step.
4. **Install** (Release build: no developer tools, no free test Pep):
   ```sh
   ./scripts/deploy.sh phone --device "Sam" --release
   ```
   The first time, this also registers their phone to your Apple ID (free accounts can only
   register a small number of devices).
5. **Trust you as the developer:** on the phone, go to Settings › General ›
   **VPN & Device Management**, tap your Apple ID under Developer App, then **Trust**.
6. **Open Fitchi:** allow Health access when asked. Steps and workouts are how it earns, so
   at least Steps and Workouts are needed. Then walk to hatch the egg (or wait: it hatches on
   its own within a day or so).

## Every week after that

Plug in, unlock, then run:
```sh
./scripts/deploy.sh phone --device "Sam" --release
```

## If something goes wrong

- **"No paired iPhone called … found":** unlock the phone, check the cable, and run
  `./scripts/deploy.sh --devices`. If it says `unpaired`, unplug, plug back in and tap Trust.
- **Signing errors in `.build/deploy-FitchiPhone.log`:** open the project in Xcode once with
  their phone connected and select it as the run destination. Xcode then sorts out the
  provisioning profile for the new device.
- **The app crashes straight away after installing:** the developer isn't trusted yet (step 5).

Later, if you join the paid program ($99/yr), TestFlight replaces all of this: your friend taps
a link, updates arrive on their own, and builds last 90 days.
