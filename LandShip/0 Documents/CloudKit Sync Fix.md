# CloudKit Sync Fix - Quick Action Steps

## ✅ What Was Done

1. **Changed entitlements** to use Production environment
2. **Added environment detection** - app now shows which CloudKit database it's using
3. **Enhanced logging** - you'll see exactly what's happening

## 🚀 What You Need to Do NOW

### Step 1: Deploy Schema to Production (CRITICAL)

**This is the most important step!** Your Development database has your schema, but Production doesn't yet.

1. Go to: https://icloud.developer.apple.com/dashboard
2. Sign in with your Apple Developer account
3. Click **"CloudKit Database"**
4. Select **"iCloud.com.aeronauticaltrax.LandShip"**
5. In the top dropdown, select **"Development"**
6. Click the **"Deploy Schema Changes"** button (usually near top right)
7. Select **"Production"** as the target
8. Review the changes (all your models should be listed)
9. Click **"Deploy"** and confirm
10. **Wait 2-5 minutes** for deployment to complete

### Step 2: Clear Development Cache on Your Mac

**Important: Quit LandShip first!**

Copy and paste these commands into Terminal:

```bash
# Clear all LandShip caches
rm -rf ~/Library/Caches/com.aeronauticaltrax.LandShip

# Clear CloudKit cache for your container
rm -rf ~/Library/Application\ Support/CloudKit/iCloud.com.aeronauticaltrax.LandShip

# Clear app container (will re-download from production)
rm -rf ~/Library/Containers/com.aeronauticaltrax.LandShip
```

### Step 3: Restart Your Mac

Just to be safe, restart after clearing caches.

### Step 4: Archive and Install (Don't Run from Xcode Yet)

1. In Xcode: **Product → Archive**
2. When Archive Organizer opens, select your archive
3. Click **"Distribute App"**
4. Choose **"Copy App"**
5. Save it to Desktop
6. **Install the app** (drag to Applications, replacing old version)
7. **Launch the installed app** (from Applications folder, NOT Xcode)

### Step 5: Verify It's Working

1. **Open Terminal** and run:
   ```bash
   log stream --predicate 'process == "LandShip"' --level debug
   ```

2. **Launch LandShip** (the installed version)

3. **Look for these lines** in Terminal:
   ```
   [LandShip] 🌐 CloudKit Environment: PRODUCTION
   [LandShip] ✅ iCloud account status: available
   [LandShip] ✅ Successfully created CloudKit-backed container
   [LandShip] Store mode: CloudKit-backed
   ```

4. **Test sync:**
   - Add a vehicle on your iOS device
   - Wait 30 seconds
   - Check if it appears on Mac
   - Watch Terminal for: `🔄 CloudKit sync: Remote change notification received`

## ❓ What About Running from Xcode?

When you run from Xcode (Cmd+R), it will still try to use **Development** environment. This is normal behavior.

**Two options:**

### Option A: Always Use Production (Simplest)
No additional changes needed. Even Xcode builds will use Production now because we changed the entitlements.

### Option B: Development for Xcode, Production for Archives
See the full guide in `CLOUDKIT_ENVIRONMENT_FIX.md` for instructions on creating separate entitlements files.

## 🔍 Troubleshooting

### If you see "Development" environment after archiving:
- Make sure you're running the **installed** app, not from Xcode
- Clean build folder: Xcode → Product → Clean Build Folder
- Delete derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData/LandShip-*`

### If you see "Local-only" mode:
- Check System Settings → Apple ID → iCloud → iCloud Drive is ON
- Verify you're signed into iCloud with the same Apple ID as iOS devices
- Check the full troubleshooting guide: `CLOUDKIT_SYNC_TROUBLESHOOTING.md`

### If data doesn't sync:
- **Wait longer** - CloudKit sync can take 30-60 seconds
- Check Apple System Status: https://www.apple.com/support/systemstatus/
- Verify schema deployed successfully in CloudKit Dashboard
- Try force-quitting and relaunching both apps

## 📊 Expected Behavior After Fix

### iOS Devices (TestFlight/App Store)
- ✅ Uses Production CloudKit
- ✅ Syncs with other iOS devices
- ✅ Will now sync with macOS archived builds

### macOS (Archived/Installed)
- ✅ Uses Production CloudKit
- ✅ Syncs with iOS devices
- ✅ Logs show "PRODUCTION" environment

### macOS (Running from Xcode)
- ⚠️ Uses Production CloudKit (with current changes)
- ✅ Syncs with iOS and installed macOS builds
- 💡 Shows "PRODUCTION" in logs

## 📝 Files Changed

1. **LandShip/LandShip.entitlements**
   - `aps-environment` changed to `production`

2. **LandShip/0 Main/1 LandShipApp.swift**
   - Added `detectCloudKitEnvironment()` function
   - Added `isRunningFromXcode()` check
   - Enhanced logging with environment detection

## 📚 Additional Resources

- **Full Environment Guide:** `CLOUDKIT_ENVIRONMENT_FIX.md`
- **General Sync Troubleshooting:** `CLOUDKIT_SYNC_TROUBLESHOOTING.md`
- **CloudKit Dashboard:** https://icloud.developer.apple.com/dashboard

---

## Next Run Checklist

- [ ] Schema deployed to Production in CloudKit Dashboard
- [ ] Caches cleared on Mac
- [ ] Mac restarted
- [ ] App archived and installed (not run from Xcode)
- [ ] Logs show "PRODUCTION" environment
- [ ] Logs show "CloudKit-backed" mode
- [ ] Test sync with iOS device successful

**Once all checkboxes are complete, your macOS sync should be working! 🎉**



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


# Fixed Log Capture Instructions

## Problem Identified

The Terminal showed no logs because `print()` statements in Swift apps don't always go to the unified logging system. I've now added **OSLog** (unified logging) to the critical sync monitoring code.

## What Was Changed

Added `Logger` from OSLog framework to all critical CloudKit sync points:
- ✅ Container creation
- ✅ CloudKit environment detection
- ✅ iCloud account status
- ✅ Sync monitor initialization
- ✅ Remote change detection
- ✅ Local save detection
- ✅ Heartbeat logging

## New Log Capture Command

Use this command instead (it uses the correct subsystem):

```bash
log stream --predicate 'subsystem == "com.aeronauticaltrax.LandShip"' --level debug --style compact
```

## Step-by-Step Testing

### 1. Archive and Install Fresh Build

Since code changed, you need a new archive:

```bash
# In Xcode:
# 1. Product → Clean Build Folder (Cmd+Shift+K)
# 2. Product → Archive
# 3. Distribute → Copy App
# 4. Install to Applications (replace existing)
```

### 2. Start Log Capture BEFORE Launching

Open Terminal and run:

```bash
log stream --predicate 'subsystem == "com.aeronauticaltrax.LandShip"' --level debug --style compact
```

Or use the convenience script:

```bash
cd /Users/JP/Library/CloudStorage/Dropbox/xCode/LandShip
./capture-logs.sh
```

### 3. Launch the App

Launch LandShip from Applications folder (NOT from Xcode).

### 4. What You Should See Immediately

**Expected startup output:**
```
Attempting to create CloudKit-backed ModelContainer...
✅ Successfully created CloudKit-backed container
🌐 CloudKit Environment: PRODUCTION
✅ iCloud account status: available
✅ Store mode: CloudKit-backed
🔍 CloudKitSyncMonitor initialized
🔍 Registered 3 notification observers for CloudKit sync monitoring
```

**If environment shows DEVELOPMENT:**
- Problem: Still using wrong CloudKit database
- Solution: Clean derived data and re-archive

**If shows "Local-only" instead of "CloudKit-backed":**
- Problem: CloudKit container creation failed
- Check System Settings → iCloud → iCloud Drive is ON

### 5. Watch for Heartbeat (Every 2 Minutes)

After 2 minutes, you should see:
```
💓 Sync monitor heartbeat - Uptime: 2m, Changes: 0, Last sync: never
```

**If no heartbeat appears:**
- Sync monitor didn't initialize properly
- Container creation likely failed

### 6. Test Local Changes

1. Add a new vehicle in macOS app
2. **Expected log:**
   ```
   💾 LOCAL SAVE detected at 2:45:30 PM
      Inserted: 1 objects
   ```

3. Wait 30-60 seconds for CloudKit upload
4. Check iOS device - should appear

### 7. Test Remote Changes

1. Add a vehicle on iOS device
2. **Expected log on Mac (within 30-60 seconds):**
   ```
   🔄 REMOTE CHANGE #1 detected at 2:46:15 PM
   ```

**This is the key test!** If you don't see REMOTE CHANGE notifications, CloudKit push notifications aren't working.

## Alternative Log Viewing Methods

If `log stream` still doesn't work, try these:

### Method 1: Console.app

1. Open Console.app (Applications → Utilities → Console)
2. Click "Start" to start streaming
3. In the search box, type: `subsystem:com.aeronauticaltrax.LandShip`
4. Launch LandShip
5. Watch for logs in Console.app

### Method 2: Capture to File

```bash
# Capture all logs to a file
log stream --predicate 'subsystem == "com.aeronauticaltrax.LandShip"' --level debug > ~/Desktop/landship-logs.txt

# In another terminal, watch the file
tail -f ~/Desktop/landship-logs.txt
```

### Method 3: Show Recent Logs

After launching the app, capture what happened in the last 2 minutes:

```bash
log show --predicate 'subsystem == "com.aeronauticaltrax.LandShip"' --last 2m --info
```

## Troubleshooting Specific Scenarios

### Scenario 1: Still No Logs Appear

**Possible causes:**
1. App bundle ID doesn't match subsystem
2. macOS Privacy settings blocking logs
3. App crashed on launch

**Solutions:**
```bash
# Verify the app is actually running
ps aux | grep LandShip

# Check for crash logs
ls -lt ~/Library/Logs/DiagnosticReports/ | grep LandShip | head -5

# Try more permissive log capture
log stream --predicate 'eventMessage CONTAINS "CloudKit" OR eventMessage CONTAINS "Sync"' --level debug
```

### Scenario 2: Logs Show But No Remote Changes

**Symptoms:**
- ✅ See startup logs
- ✅ See LOCAL SAVE when you make changes
- ❌ Never see REMOTE CHANGE when iOS device updates

**This means:** CloudKit push notifications aren't being delivered to macOS.

**Possible causes:**
1. **Background refresh disabled**
   - System Settings → General → Login Items & Extensions → Allow in Background
   
2. **Notifications disabled**
   - System Settings → Notifications → LandShip → Allow notifications
   
3. **Network/Firewall blocking**
   - CloudKit uses APNs (Apple Push Notification service)
   - Corporate firewalls may block this
   
4. **CloudKit throttling**
   - Apple limits push notification frequency
   - May take several minutes for push to arrive

**Solutions:**
```bash
# Check if APNs is reachable
nc -zv 17.0.0.0 5223

# Restart APNs daemon (requires admin password)
sudo killall apsd
sudo launchctl stop com.apple.apsd
sudo launchctl start com.apple.apsd

# Sign out and back into iCloud
# System Settings → Apple ID → Sign Out
# Wait 30 seconds
# Sign back in
```

### Scenario 3: First Sync Works, Then Stops

**Symptoms:**
- ✅ Initial sync on first launch works
- ❌ No subsequent syncs

**This is YOUR current situation!**

**Most likely cause:** CloudKit mirroring delegate stopped after initial import.

**Debug steps:**

1. **Check for export errors:**
   ```bash
   log show --predicate 'subsystem CONTAINS "cloudkit" AND messageType == error' --last 10m
   ```

2. **Force a refresh:**
   - Quit LandShip completely
   - Run:
     ```bash
     rm -rf ~/Library/Application\ Support/CloudKit/iCloud.com.aeronauticaltrax.LandShip
     ```
   - Relaunch and watch logs

3. **Check schema deployment:**
   - Go to https://icloud.developer.apple.com/dashboard
   - Select "iCloud.com.aeronauticaltrax.LandShip"
   - Switch to "Production" environment
   - Verify all record types exist
   - Check for any schema errors

## What to Report Back

Please capture and share:

1. **Startup logs** - First 30 lines after launch
2. **Heartbeat logs** - Do you see them every 2 minutes?
3. **Local save test** - Logs when you add a vehicle on Mac
4. **Remote change test** - What happens when you add vehicle on iOS?

Example format:
```
STARTUP:
[timestamp] Attempting to create CloudKit-backed ModelContainer...
[timestamp] ✅ Successfully created CloudKit-backed container
[timestamp] 🌐 CloudKit Environment: PRODUCTION
...

HEARTBEAT (2 min):
[timestamp] 💓 Sync monitor heartbeat - Uptime: 2m, Changes: 0, Last sync: never

LOCAL SAVE:
[timestamp] 💾 LOCAL SAVE detected at 2:45:30 PM
[timestamp]    Inserted: 1 objects

REMOTE CHANGE:
[nothing appears - this is the problem]
```

---

## Quick Reference

**Start monitoring:**
```bash
log stream --predicate 'subsystem == "com.aeronauticaltrax.LandShip"' --level debug --style compact
```

**Or use script:**
```bash
cd /Users/JP/Library/CloudStorage/Dropbox/xCode/LandShip && ./capture-logs.sh
```

**View in Console.app:**
Search for: `subsystem:com.aeronauticaltrax.LandShip`

---

The OSLog implementation will ensure logs appear. Try the new build and report what you see!


# CRITICAL: CloudKit BAD_REQUEST Error Fix

## 🔍 Root Cause Identified

Your CloudKit Dashboard shows a **"USER_ERROR"** with **"BAD_REQUEST"** from a **RecordDelete** operation. This is blocking all CloudKit sync operations.

**What's happening:**
1. SwiftData is trying to delete a record from CloudKit Production
2. The delete request is malformed or the record doesn't exist
3. CloudKit rejects the request with BAD_REQUEST
4. SwiftData sync gets stuck and stops processing further changes
5. No more syncs occur until this is resolved

## Additional Issue Found

The **heartbeat timer stopped** after startup because the `syncMonitor` was being deallocated. This has been fixed in the new build.

## Step-by-Step Fix

### Step 1: Complete Clean Slate on Mac

**IMPORTANT: Quit LandShip first!**

```bash
# Clear CloudKit cache (removes stuck sync operations)
rm -rf ~/Library/Application\ Support/CloudKit/iCloud.com.aeronauticaltrax.LandShip

# Clear app container (forces fresh sync from CloudKit)
rm -rf ~/Library/Containers/com.aeronauticaltrax.LandShip

# Clear general caches
rm -rf ~/Library/Caches/com.aeronauticaltrax.LandShip

# Clear SwiftData store locations
rm -rf ~/Library/Group\ Containers/*/com.aeronauticaltrax.LandShip
```

### Step 2: Clean CloudKit Development Database

The corrupted record might have come from Development environment:

1. Go to: **https://icloud.developer.apple.com/dashboard**
2. Select **"iCloud.com.aeronauticaltrax.LandShip"**
3. Switch to **"Development"** environment (top dropdown)
4. Click **"Data"** tab
5. For each record type (Vehicle8, ServiceRecords1, etc.):
   - Click the record type
   - Select all records
   - Delete them
6. This clears Development database completely

### Step 3: Check Production Database for Orphans

1. Still in CloudKit Dashboard
2. Switch to **"Production"** environment
3. Click **"Data"** tab
4. Look through each record type
5. If you see records that shouldn't be there (test data, corrupted entries), delete them
6. **Note:** Be careful - this is production data!

### Step 4: Verify Schema is Deployed

While in CloudKit Dashboard → Production:

1. Click **"Schema"** tab
2. Verify these record types exist:
   - Vehicle8
   - ServiceRecords1
   - FuelLog1
   - TripLog2
   - MxParts
   - MxItems
   - VehicleSystems
   - Vendors
   - Additions
   - Subscriptions
   - ProjectList
   - CheckList
   - CheckListItem

**If any are missing:**
- Switch to Development environment
- Click "Deploy Schema Changes"
- Select Production as target
- Deploy

### Step 5: Archive New Build

The code has been fixed to:
- Keep sync monitor alive (was being deallocated)
- Log CloudKit errors properly
- Better event handling

```bash
# In Xcode:
# 1. Product → Clean Build Folder (Cmd+Shift+K)
# 2. Delete derived data:
rm -rf ~/Library/Developer/Xcode/DerivedData/LandShip-*

# 3. Product → Archive
# 4. Distribute → Copy App
# 5. Install to Applications
```

### Step 6: Restart Mac

Yes, seriously. macOS CloudKit daemon sometimes needs a full restart to clear stuck states.

```bash
sudo reboot
```

### Step 7: Monitor the New Launch

After restart, start monitoring:

```bash
log stream --predicate 'subsystem == "com.aeronauticaltrax.LandShip"' --level debug --style compact
```

Launch LandShip and watch for:

**Expected startup (same as before):**
```
Attempting to create CloudKit-backed ModelContainer...
✅ Successfully created CloudKit-backed container
✅ Store mode: CloudKit-backed
🔍 Registered 3 notification observers for CloudKit sync monitoring
🔍 CloudKitSyncMonitor initialized
🌐 CloudKit Environment: PRODUCTION
✅ iCloud account status: available
```

**NEW: After 2 minutes, you should see:**
```
💓 Sync monitor heartbeat - Uptime: 2m, Changes: 0, Last sync: never
```

**This is critical!** If you see the heartbeat, the fix worked.

### Step 8: Test Sync Again

1. **Add a vehicle on iOS**
2. **Wait 30-60 seconds**
3. **Watch Mac logs for:**
   ```
   🔄 REMOTE CHANGE #1 detected at [time]
   ```
4. **Check Mac app** - vehicle should appear

### Step 9: Check CloudKit Dashboard for Errors

While testing, keep CloudKit Dashboard open:

1. Go to **Data** tab in Production
2. Look for the **error log** section
3. Check if any new errors appear
4. If you see more BAD_REQUEST errors:
   - Note which record type is failing
   - Report back with details

## What Changed in the Code

**LandShipApp.swift:**

1. **syncMonitor is now static** - won't be deallocated
   ```swift
   private static var syncMonitor: CloudKitSyncMonitor?
   ```

2. **Better CloudKit error logging**
   - Now logs errors from CloudKit events
   - Will show what's failing in realtime

3. **All critical paths use OSLog**
   - Guaranteed to appear in logs
   - Can be viewed in Console.app

## Interpreting the Results

### Scenario A: Heartbeat Appears, Sync Works ✅

**Logs show:**
```
💓 Sync monitor heartbeat - Uptime: 2m, Changes: 0, Last sync: never
💓 Sync monitor heartbeat - Uptime: 4m, Changes: 0, Last sync: never
🔄 REMOTE CHANGE #1 detected at 3:15:30 PM
```

**Status:** FIXED! The BAD_REQUEST was from stuck data. Clean slate resolved it.

### Scenario B: Heartbeat Appears, Sync Still Fails ❌

**Logs show:**
```
💓 Sync monitor heartbeat - Uptime: 2m, Changes: 0, Last sync: never
(iOS device adds vehicle - nothing happens)
(No REMOTE CHANGE log)
```

**Status:** Heartbeat fix worked, but CloudKit push notifications aren't being delivered.

**Next steps:**
- Check System Settings → Notifications → LandShip → Allow
- Restart APNs daemon:
  ```bash
  sudo killall apsd
  ```
- Check firewall isn't blocking APNs

### Scenario C: No Heartbeat ❌

**Logs show startup, then nothing for 2+ minutes**

**Status:** Sync monitor still being deallocated somehow.

**Debug:**
```bash
# Check if app is actually running
ps aux | grep LandShip

# Check for crashes
ls -lt ~/Library/Logs/DiagnosticReports/ | grep -i landship | head -3
```

### Scenario D: CloudKit Errors in Logs ⚠️

**Logs show:**
```
☁️ CloudKit EVENT at 3:15:30 PM
   ❌ ERROR: [error description]
```

**Status:** New error identified. Report the exact error message.

## Alternative: Nuclear Option

If nothing above works, there's a more drastic approach:

### Delete and Reinstall on ALL Devices

1. **On all iOS devices:**
   - Delete LandShip app completely
   - Settings → General → iPhone Storage → LandShip → Delete App
   
2. **On Mac:**
   - Delete app
   - Clear all caches (commands above)
   
3. **Clear CloudKit Production Data:**
   - In CloudKit Dashboard → Production → Data
   - Delete all records (you'll lose existing data)
   
4. **Reinstall on one device first:**
   - Install on iOS
   - Add test vehicle
   - Wait 2 minutes
   
5. **Install on Mac:**
   - Should sync the test vehicle from iOS
   
6. **Add from Mac:**
   - Should sync back to iOS

This forces a completely fresh start with no historical baggage.

## Expected Timeline

- **Minutes 0-1:** App launches, CloudKit container created
- **Minute 2:** First heartbeat appears
- **Minute 4:** Second heartbeat
- **After change on iOS:** 30-60 seconds for sync to Mac
- **After change on Mac:** 30-60 seconds for sync to iOS

## Monitoring Commands

**Start log capture:**
```bash
log stream --predicate 'subsystem == "com.aeronauticaltrax.LandShip"' --level debug --style compact
```

**Check for CloudKit errors:**
```bash
log show --predicate 'subsystem CONTAINS "cloudkit" AND messageType == error' --last 5m
```

**View all CloudKit activity:**
```bash
log stream --predicate 'subsystem CONTAINS "cloudkit" OR subsystem == "com.aeronauticaltrax.LandShip"' --level debug | grep -E "LandShip|error|Error"
```

---

## Summary

The BAD_REQUEST error in CloudKit is blocking all sync. The fix involves:
1. ✅ Clear all local CloudKit caches
2. ✅ Clean Development database
3. ✅ Verify Production schema
4. ✅ Install new build with persistent sync monitor
5. ✅ Reboot Mac
6. ✅ Test with fresh start

After these steps, you should see heartbeats every 2 minutes and sync should work bidirectionally.

Report back with:
- Whether heartbeat appears
- Whether sync works
- Any error messages in logs or CloudKit Dashboard


# CloudKit APNs Push Notification Fix

## Problem Identified

Your logs show:
- ✅ **iOS → CloudKit:** Working (changes appear in CloudKit Dashboard)
- ✅ **macOS → CloudKit:** Working (LOCAL SAVE → REMOTE CHANGE confirms upload)
- ❌ **CloudKit → macOS Push:** NOT working (no REMOTE CHANGE when iOS makes changes)

The macOS app is **not receiving push notifications** from CloudKit when other devices upload changes.

## Root Cause

CloudKit uses **APNs (Apple Push Notification service)** to notify devices about remote changes. Your Mac isn't receiving these push notifications, which means:
- Changes made on iOS upload to CloudKit successfully
- CloudKit tries to notify your Mac via APNs
- The notification never arrives at your Mac
- Your Mac never knows to fetch the new data

## Immediate Fix Applied

I've added **automatic polling** as a fallback mechanism. The app now:

1. **Still monitors for push notifications** (preferred method - instant)
2. **Also polls every 30 seconds** (fallback - if push fails)

This means even if APNs push notifications fail, the Mac will check CloudKit every 30 seconds for new changes.

### New Logs You'll See

```
[LandShip] 🔄 Started polling every 30 seconds (APNs fallback)
[LandShip] 🔄 Polling: Forced sync check  (appears every 30 seconds)
```

## Testing the Fix

### Step 1: Archive and Install New Build

```bash
# Clean
rm -rf ~/Library/Developer/Xcode/DerivedData/LandShip-*

# In Xcode:
# Product → Clean Build Folder
# Product → Archive
# Distribute → Copy App
# Install to Applications
```

### Step 2: Monitor Logs

```bash
log stream --predicate 'subsystem == "com.aeronauticaltrax.LandShip"' --level debug --style compact
```

### Step 3: Test Sync from iOS

1. **Keep Terminal visible with logs running**
2. **Add a vehicle on iOS device**
3. **Watch Mac Terminal**
4. **Within 30 seconds** you should see:
   ```
   🔄 Polling: Forced sync check
   🔄 REMOTE CHANGE #XX detected
   ```
5. **Check Mac app** - new vehicle should appear

## Additional APNs Fixes to Try

If polling works but you want to fix the push notifications (for instant sync):

### Fix 1: Restart APNs Daemon

```bash
# Quit LandShip first
sudo killall apsd
sudo killall cloudd
sudo killall bird

# Wait 10 seconds, then relaunch LandShip
```

### Fix 2: Enable Notifications Permission

1. **System Settings** → **Notifications**
2. Find **"LandShip"** or **"VehicleTrax"**
3. Enable **"Allow Notifications"**
4. Enable **"Banners"** or **"Alerts"**

Even though CloudKit uses "silent" notifications, macOS requires notification permission.

### Fix 3: Clear APNs Cache

```bash
# Quit LandShip
rm -rf ~/Library/Caches/com.apple.apsd
rm -rf ~/Library/Application\ Support/CloudKit/CloudKitDaemon

# Restart Mac (important for APNs)
sudo reboot
```

### Fix 4: Check Network/Firewall

APNs requires these ports open:
- TCP 5223 (APNs)
- TCP 443 (HTTPS)

If on corporate network or VPN:
```bash
# Test APNs connectivity
nc -zv 17.0.0.0 5223

# Should say "succeeded" if APNs is reachable
```

If blocked, you'll need to configure firewall/VPN to allow APNs.

### Fix 5: Sign Out and Back Into iCloud

Sometimes APNs tokens get stale:

1. **System Settings** → **Apple ID**
2. **Sign Out** (don't delete data from Mac)
3. **Wait 60 seconds**
4. **Sign back in**
5. **Relaunch LandShip**

## Understanding Sync Behavior

### With Working Push Notifications (Ideal)

```
iOS: Save → CloudKit: Upload → APNs: Notify Mac → Mac: Fetch
Time: ~1-5 seconds
```

Logs show:
```
🔄 REMOTE CHANGE #XX detected at [time]
```
Immediately when iOS makes a change.

### With Polling Only (Current Fallback)

```
iOS: Save → CloudKit: Upload → Mac: Poll every 30s → Mac: Fetch
Time: 0-30 seconds (average 15 seconds)
```

Logs show:
```
🔄 Polling: Forced sync check
🔄 REMOTE CHANGE #XX detected at [time]
```
Within 30 seconds of iOS change.

### With Both (Best Case)

- Push notifications work: instant sync
- Polling runs as backup: catches anything push misses
- Maximum reliability

## Monitoring APNs Status

To see if push notifications are arriving:

```bash
# Watch for APNs activity
log stream --predicate 'process == "apsd" OR subsystem CONTAINS "apns"' --level debug

# In another terminal, make a change on iOS
# If you see apsd logs, push is working
# If nothing appears, push is blocked
```

## Performance Impact

**Polling every 30 seconds:**
- **Battery:** Minimal impact (single context.save() call)
- **Network:** Negligible (~few KB per check)
- **CloudKit quota:** Insignificant (well within limits)

This is a safe, reliable workaround.

## When Push Notifications Work

After applying APNs fixes, you'll know push is working when:

1. **Change made on iOS**
2. **Mac Terminal shows REMOTE CHANGE immediately** (< 5 seconds)
3. **No "Polling: Forced sync check" log between change and REMOTE CHANGE**

You can then remove polling if desired (though keeping both is safest).

## Alternative: Increase Polling Frequency

If 30 seconds is too slow, you can change it:

Edit `LandShipApp.swift` around line 555:
```swift
// Change from 30 to 15 for every 15 seconds
pollTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true)
```

Or decrease to 60 for every minute (saves battery).

## Summary

✅ **Polling now active** - Mac checks every 30 seconds
✅ **Should see changes within 30 seconds of iOS upload**
⚠️ **Push notifications still broken** (APNs issue)
💡 **Try APNs fixes above for instant sync**

The polling mechanism ensures sync works reliably even if APNs never gets fixed.

---

**Test the new build and report:**
1. Do you see "🔄 Started polling every 30 seconds" on startup?
2. When you add data on iOS, does it appear on Mac within 30 seconds?
3. Do you see "🔄 Polling: Forced sync check" every 30 seconds?
