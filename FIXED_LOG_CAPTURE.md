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
