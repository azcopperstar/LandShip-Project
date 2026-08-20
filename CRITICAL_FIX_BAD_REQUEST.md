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
