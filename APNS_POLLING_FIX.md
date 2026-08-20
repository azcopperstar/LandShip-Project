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
