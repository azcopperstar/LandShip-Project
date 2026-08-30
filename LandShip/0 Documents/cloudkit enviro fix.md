# CloudKit Environment — Development vs Production

> **Corrected 2026-08-30.** An earlier version of this document claimed that
> `aps-environment` selects which CloudKit database the app uses. **That is wrong.**
> `aps-environment` controls APNs (push notifications) only. The CloudKit database is
> selected exclusively by the `com.apple.developer.icloud-container-environment`
> entitlement. Acting on the old advice is what kept macOS builds pointed at the
> live Production database.

## How the environment is actually chosen

Per [`CKContainer`](https://developer.apple.com/documentation/CloudKit/CKContainer#Testing-Your-Code-Using-the-Development-Container):

> At runtime, CloudKit uses your app's `com.apple.developer.icloud-container-environment`
> entitlement to discover whether you're using a `Development` or `Production` version
> of your provisioning profile.

Two consequences worth internalising:

- **If the key is absent, macOS builds run from Xcode use Production.** This is the
  trap. iOS development builds default to Development, so the two platforms behave
  differently and macOS silently reads and writes live user data.
- **APNs must match the container environment.** A Development container with
  `aps-environment: production` will not receive remote-change pushes, so sync appears
  broken for reasons unrelated to the database.

## Current setup (as of 2026-08-30)

Target `VehicleTrax` uses one build setting that self-selects the right file:

```
CODE_SIGN_ENTITLEMENTS = LandShip/LandShip-$(CONFIGURATION).entitlements
```

| File | icloud-container-environment | aps-environment |
|------|------------------------------|-----------------|
| `LandShip/LandShip-Debug.entitlements` | `Development` | `development` |
| `LandShip/LandShip-Release.entitlements` | `Production` | `production` |

`LandShip/LandShip.entitlements` is no longer referenced by the build.

Note: adding a new build configuration requires a matching
`LandShip-<Config>.entitlements` file, or signing will fail.

The `$(CONFIGURATION)` indirection is used because Xcode's automation cannot create
user-defined build settings or write per-configuration values for
`CODE_SIGN_ENTITLEMENTS`. One target-level value that expands per configuration
achieves the same result.

## Verifying which environment a build is signed for

Do not trust the source `.entitlements` file — check what was actually signed:

```bash
# Debug build for My Mac
codesign -d --entitlements :- \
  ~/Library/Developer/Xcode/DerivedData/LandShip-*/Build/Products/Debug/VehicleTrax.app \
  2>/dev/null | plutil -p - | grep -E "icloud-container-environment|aps-environment"

# Installed / archived build
codesign -d --entitlements :- /Applications/VehicleTrax.app \
  2>/dev/null | plutil -p - | grep -E "icloud-container-environment|aps-environment"
```

Expected: `Development` / `development` for Debug, `Production` / `production` for Release.

The app also logs its environment at launch:

```
🌐 CloudKit Environment: DEVELOPMENT
✅ iCloud account status: available
```

Be aware this log line is derived from the `DEBUG` compilation condition, not read
from the signed entitlement. It is a sanity check, not proof — `codesign` above is
the authority.

## Confirming that Development *data* is in use

The strongest signal is the data itself. The Development database is a separate,
initially empty dataset:

1. Clear the local store (see below) and launch the Debug build.
2. An empty app — no vehicles — means you are on Development.
3. Your real fleet appearing means you are still on Production.

Then confirm in [CloudKit Console](https://icloud.developer.apple.com/dashboard):
select the container, switch the environment dropdown to **Development**, open
Records, and query for `CD_Vehicle8`. Records created by the Debug build appear
there and must not appear under Production.

## The local store is shared between configurations

Debug and Release use the same bundle identifier, so they share one sandbox
container:

```
~/Library/Containers/com.aeronauticaltrax.LandShip
```

The store inside it carries CloudKit sync metadata (change tokens, record names)
bound to whichever environment last used it. **Clear the container whenever you flip
environments**, or you will debug metadata confusion instead of real behaviour:

```bash
# Quit the app first
rm -rf ~/Library/Containers/com.aeronauticaltrax.LandShip
```

`~/Library` is hidden in Finder. Reach it with Go → Go to Folder, or:

```bash
open ~/Library/Containers/com.aeronauticaltrax.LandShip
```

Export via the app's Backup/Restore feature first if the local data matters.

## Understanding the two environments

### Development
- Used by builds signed with `icloud-container-environment: Development`
- Schema is created automatically as the app runs and can be edited freely in Console
- Data is separate from Production and can be reset
- The iOS Simulator only ever uses Development, regardless of entitlement

### Production
- Used by App Store and TestFlight builds, and by Release builds
- Schema is **append-only**: record types and fields can be added but never deleted
  or retyped once deployed
- Requires an explicit Deploy Schema Changes from Development

## Same account, different database

Development and Production are two databases inside the **same container for the
same Apple Account**. There is no separate "development iCloud account", and no
per-app account selection on macOS — CloudKit uses the account of the current macOS
login session.

To test against a genuinely different Apple Account on macOS, create a second macOS
login account and sign it into the test account. Fast User Switching allows both
sessions to run at once, which is useful for observing sync between two accounts on
one machine.

## Deploying schema to Production

1. Sign in to <https://icloud.developer.apple.com/dashboard>
2. Select the CloudKit Database app and choose `iCloud.com.aeronauticaltrax.LandShip`
3. Select **Deploy Schema Changes**
4. Review the diff carefully — a non-empty diff means Production was missing fields,
   which causes `BAD_REQUEST` on every save from a Production build
5. Deploy, then wait a few minutes for propagation

## Monitoring sync

```bash
log stream --predicate 'subsystem == "com.aeronauticaltrax.LandShip"' \
  --level debug --style compact
```

Export and import failures now log the real `CKError`, including
`partialErrorsByItemID`, which names the specific record the server rejected.

---
**Last updated:** 2026-08-30
**Related:** `CloudKit Sync Fix.md` (historical troubleshooting log — see its own
correction notice)
