# Sync Stopped After First Launch - Diagnostic Steps

## What's Happening

You've reported:
- ✅ App synced once on first launch
- ❌ Then sync stopped completely
- ❌ No log entries in Terminal after first launch
- ❌ No CloudKit sync activity

This suggests the app might be silently failing or CloudKit is no longer attempting to sync.

## What Was Just Added

I've added **comprehensive CloudKit sync monitoring** that will give us much more visibility:

### New Logging Features

1. **Heartbeat Monitor** - Logs every 2 minutes to confirm monitoring is active
   ```
   [LandShip] 💓 Sync monitor heartbeat - Uptime: 4m, Changes: 0, Last sync: never
   ```

2. **Remote Change Detection** - Logs when CloudKit pushes changes to the app
   ```
   [LandShip] 🔄 REMOTE CHANGE #1 detected at 3:45:23 PM
   ```

3. **Local Save Detection** - Logs when you make changes locally
   ```
   [LandShip] 💾 LOCAL SAVE detected at 3:45:30 PM
   [LandShip]    Inserted: 1 objects
   ```

4. **CloudKit Events** - Logs CloudKit import/export events
   ```
   [LandShip] ☁️ CloudKit EVENT at 3:45:35 PM
   ```

5. **Startup Diagnostics** - Enhanced startup logging
   ```
   [LandShip] 🌐 CloudKit Environment: PRODUCTION
   [LandShip] ✅ Successfully created CloudKit-backed container
   [LandShip] 🔍 CloudKitSyncMonitor initialized
   ```

## How to Test the New Logging

### Step 1: Archive and Install Fresh Build

```bash
# 1. Clean build folder
# Xcode → Product → Clean Build Folder (Cmd+Shift+K)

# 2. Archive
# Xcode → Product → Archive

# 3. Distribute and install
# - Select archive → Distribute App → Copy App
# - Install to Applications folder
# - Replace existing version
```

### Step 2: Start Monitoring BEFORE Launching

Open Terminal and run:

```bash
log stream --predicate 'process == "LandShip"' --level debug
```

Keep this Terminal window open and visible.

### Step 3: Launch the App

1. Launch LandShip from Applications folder
2. **Watch Terminal immediately** for these startup messages:

**Expected Good Output:**
```
[LandShip] App Version: X.X.X
[LandShip] Build: RELEASE
[LandShip] 🌐 CloudKit Environment: PRODUCTION
[LandShip] Attempting to create CloudKit-backed ModelContainer...
[LandShip] ✅ Successfully created CloudKit-backed container
[LandShip] Store mode: CloudKit-backed
[LandShip] ✅ iCloud account status: available
[LandShip] 🔍 CloudKitSyncMonitor initialized
[LandShip] 🔍 Registered observers for:
  - NSPersistentStoreRemoteChange (remote sync)
  - NSManagedObjectContextDidSave (local changes)
  - CloudKit container events
```

**If you see this instead, there's a problem:**
```
[LandShip] 🌐 CloudKit Environment: DEVELOPMENT  ← WRONG!
[LandShip] ⚠️ Failed to create CloudKit container  ← PROBLEM!
[LandShip] Store mode: Local-only  ← NOT SYNCING!
[LandShip] ❌ iCloud account status: noAccount  ← PROBLEM!
```

### Step 4: Watch for Heartbeat

After launch, you should see a heartbeat every 2 minutes:

```
[LandShip] 💓 Sync monitor heartbeat - Uptime: 2m, Changes: 0, Last sync: never
[LandShip] 💓 Sync monitor heartbeat - Uptime: 4m, Changes: 0, Last sync: never
```

**If you DON'T see heartbeats:** The sync monitor isn't running (meaning CloudKit container creation failed).

### Step 5: Test Local Changes

1. **Add a new vehicle** in the macOS app
2. **Watch Terminal** - you should see:
   ```
   [LandShip] 💾 LOCAL SAVE detected at 3:45:30 PM
   [LandShip]    Inserted: 1 objects
   ```

3. **Wait 30-60 seconds** - CloudKit should upload this change
4. **Check iOS device** - the new vehicle should appear

**If you see the LOCAL SAVE but nothing appears on iOS:**
- CloudKit might not be uploading changes
- Check next section for additional diagnostics

### Step 6: Test Remote Changes

1. **Add a vehicle on iOS device**
2. **Watch Terminal on Mac** - you should see within 30-60 seconds:
   ```
   [LandShip] 🔄 REMOTE CHANGE #1 detected at 3:46:15 PM
   ```

**If you DON'T see REMOTE CHANGE notification:**
- CloudKit isn't pushing changes to macOS
- This is the core problem!

## Possible Issues and Solutions

### Issue 1: No Log Output At All

**Symptom:** Terminal shows nothing when you launch the app

**Cause:** The `log stream` command might not be capturing the app's logs

**Solution:** Try this alternative:
```bash
# More permissive log capture
log stream --predicate 'eventMessage CONTAINS "LandShip"' --info --debug

# Or watch the system log file directly
tail -f /var/log/system.log | grep LandShip
```

### Issue 2: "CloudKit Environment: DEVELOPMENT" After Archiving

**Symptom:** Archived app still shows DEVELOPMENT environment

**Cause:** Xcode might be caching old entitlements

**Solution:**
```bash
# Delete derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/LandShip-*

# Clean and rebuild
# Xcode → Product → Clean Build Folder
# Then archive again
```

### Issue 3: "Local-only" Mode in Production Build

**Symptom:** Logs show "Store mode: Local-only (sync unavailable)"

**Cause:** CloudKit container creation is failing

**Solution:**
1. Check System Settings → Apple ID → iCloud → iCloud Drive is ON
2. Verify you're signed into iCloud
3. Check Console.app for CloudKit errors:
   ```bash
   log show --predicate 'subsystem CONTAINS "cloudkit"' --last 5m --info
   ```

### Issue 4: Heartbeat Shows "Changes: 0" Forever

**Symptom:** Heartbeat logs but change count never increases

**Cause:** CloudKit notifications aren't being received

**Possible reasons:**
- Network firewall blocking CloudKit
- CloudKit Push notifications disabled
- Background refresh disabled

**Solution:**
1. Check network connectivity
2. System Settings → Notifications → LandShip → ensure notifications allowed
3. Restart the Mac (seriously, this helps with CloudKit sometimes)

### Issue 5: LOCAL SAVE Logs But No Sync to iOS

**Symptom:** You see local saves but changes don't appear on other devices

**Cause:** CloudKit export might be failing silently

**Solution:**
```bash
# Check for CloudKit export errors
log show --predicate 'process == "LandShip" AND eventMessage CONTAINS "export"' --last 10m --info
log show --predicate 'subsystem CONTAINS "cloudkit" AND eventMessage CONTAINS "error"' --last 10m --info
```

### Issue 6: First Sync Works, Then Nothing

**Symptom:** Initial sync on first launch, then silence

**Cause:** This is the classic "CloudKit stopped syncing" problem

**Most likely causes:**
1. **CloudKit throttling** - Apple limits sync frequency
2. **Token expiration** - CloudKit auth token needs refresh
3. **Schema mismatch** - Development vs Production schemas differ
4. **Network change** - Mac switched networks and CloudKit didn't reconnect

**Solutions:**
```bash
# Force CloudKit to reconnect
# 1. Quit LandShip
# 2. Clear CloudKit cache
rm -rf ~/Library/Application\ Support/CloudKit/iCloud.com.aeronauticaltrax.LandShip

# 3. Sign out of iCloud and back in
# System Settings → Apple ID → Sign Out
# (Wait 30 seconds)
# System Settings → Sign In with Apple ID

# 4. Restart Mac
# 5. Launch LandShip again
```

## Advanced Diagnostics

If the above doesn't help, capture detailed CloudKit logs:

```bash
# Create a log file with ALL CloudKit activity
log stream --predicate 'subsystem CONTAINS "cloudkit" OR process == "LandShip"' --level debug > ~/Desktop/cloudkit-debug.log
```

Let this run while you:
1. Launch the app
2. Make a change on macOS
3. Wait 2 minutes
4. Make a change on iOS
5. Wait 2 minutes

Then stop the log (Ctrl+C) and examine `~/Desktop/cloudkit-debug.log`.

Look for:
- `NSCloudKitMirroringDelegate` errors
- `CKError` messages
- `export` or `import` failures
- Authentication problems

## What To Report Back

Please share:

1. **Startup logs** - The first 50 lines after launching
2. **Heartbeat status** - Are you seeing the heartbeats?
3. **Local save logs** - Do you see 💾 LOCAL SAVE messages?
4. **Remote change logs** - Do you see 🔄 REMOTE CHANGE messages?
5. **Environment** - What does "CloudKit Environment" show?
6. **Store mode** - "CloudKit-backed" or "Local-only"?

This will help pinpoint exactly where the sync is failing!

---

**Next Steps:** Archive, install, and monitor Terminal for the enhanced logging output.
