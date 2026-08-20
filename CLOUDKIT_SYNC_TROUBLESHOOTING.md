# CloudKit Sync Troubleshooting Guide for LandShip

## Overview
This guide helps troubleshoot CloudKit sync issues when iOS devices sync successfully but macOS doesn't.

## Changes Made

### Enhanced Logging Added to LandShipApp.swift
The app now includes comprehensive CloudKit diagnostics that will print to the console when the app launches:
- ✅ iCloud account status
- 🔄 CloudKit container creation status
- 💡 Platform-specific troubleshooting hints
- 🖥️ macOS-specific guidance

## Step-by-Step Troubleshooting

### Step 1: Check Console Logs

1. **Open Console.app** on your Mac (Applications → Utilities → Console)
2. **Clear** the console (Cmd+K)
3. **Launch LandShip** on macOS
4. **Filter** logs by typing "LandShip" in the search box
5. **Look for** these key messages:

**Good signs (sync should work):**
```
[LandShip] ✅ iCloud account status: available
[LandShip] ✅ Successfully created CloudKit-backed container
[LandShip] Store mode: CloudKit-backed
```

**Problem indicators:**
```
[LandShip] ❌ iCloud account status: noAccount
[LandShip] ❌ iCloud account status: restricted
[LandShip] ⚠️ Failed to create CloudKit container
[LandShip] Store mode: Local-only (sync unavailable)
```

### Step 2: Verify macOS System Settings

1. **Open System Settings**
2. **Click on your Apple ID** (top of sidebar)
3. **Verify you're signed in** with the same Apple ID as your iOS devices
4. **Click "iCloud"** in the sidebar
5. **Ensure "iCloud Drive" is enabled** (toggle ON)
6. **Click "iCloud Drive" → Options**
7. **Check if "LandShip" appears** in the app list and is enabled

### Step 3: Check Network & Permissions

Run these commands in Terminal to verify CloudKit connectivity:

```bash
# Check if signed into iCloud
defaults read MobileMeAccounts Accounts

# Check iCloud Drive status
brctl log --wait --shorten

# Check app's CloudKit permissions
plutil -p ~/Library/Containers/com.aeronauticaltrax.LandShip/Data/Library/Preferences/com.aeronauticaltrax.LandShip.plist
```

### Step 4: Clear CloudKit Cache (If Needed)

If the above checks pass but sync still doesn't work, try clearing the local cache:

```bash
# IMPORTANT: Quit LandShip first!

# Clear application caches
rm -rf ~/Library/Caches/com.aeronauticaltrax.LandShip

# Clear CloudKit cache (be careful with this - it forces a re-sync)
rm -rf ~/Library/Application\ Support/CloudKit

# Optional: Clear app support data (will re-download from iCloud)
# rm -rf ~/Library/Containers/com.aeronauticaltrax.LandShip/Data/Library/Application\ Support
```

**Then:**
1. Restart your Mac
2. Launch LandShip
3. Watch Console.app for sync activity

### Step 5: Enable Detailed CloudKit Logging

For maximum debugging detail:

1. **Open Xcode**
2. **Select the LandShip scheme** (top toolbar, next to device selector)
3. **Edit Scheme** (Product → Scheme → Edit Scheme, or Cmd+<)
4. **Select "Run" → "Arguments"**
5. **Add these Environment Variables:**
   - Name: `com.apple.coredata.cloudkit.log`
     Value: `3`
   - Name: `com.apple.coredata.logging.oslog`
     Value: `1`

6. **Run the app from Xcode**
7. **Check Console.app** filtered by "CloudKit" for detailed sync logs

### Step 6: Check CloudKit Dashboard

Verify your CloudKit container is properly configured:

1. Go to https://icloud.developer.apple.com/dashboard
2. Sign in with your Apple Developer account
3. Select **"CloudKit Database"**
4. Find **"iCloud.com.aeronauticaltrax.LandShip"** container
5. Check the **Development** vs **Production** environment
6. Verify the schema includes all your model types:
   - Vehicle8
   - ServiceRecords1
   - FuelLog1
   - TripLog2
   - Additions
   - Subscriptions
   - ProjectList
   - CheckList
   - CheckListItem
   - (and others)

### Step 7: Verify Entitlements

The app's entitlements are configured correctly at:
`LandShip/LandShip.entitlements`

Confirmed settings:
- ✅ `com.apple.developer.icloud-services`: CloudKit
- ✅ `com.apple.developer.icloud-container-identifiers`: iCloud.com.aeronauticaltrax.LandShip
- ✅ `com.apple.security.app-sandbox`: enabled
- ✅ `com.apple.security.network.client`: enabled

### Step 8: Common macOS-Specific Issues

#### Issue: "Store mode: Local-only" on macOS but "CloudKit-backed" on iOS

**Possible causes:**
1. **Different Apple IDs**: Mac and iOS using different accounts
2. **iCloud Drive disabled on Mac**: System Settings → Apple ID → iCloud → iCloud Drive OFF
3. **Network restrictions**: Corporate firewall blocking CloudKit
4. **Sandbox restrictions**: App sandbox preventing CloudKit access

**Solutions:**
- Sign out and back into iCloud on Mac
- Disable and re-enable iCloud Drive
- Check corporate VPN/firewall settings
- Verify app has network access in Security & Privacy

#### Issue: Initial sync works but stops updating

**Possible cause:** CloudKit sync conflicts or stale tokens

**Solution:**
```bash
# Force CloudKit to re-authenticate
rm -rf ~/Library/Application\ Support/CloudKit/iCloud.com.aeronauticaltrax.LandShip

# Restart the app
```

#### Issue: "iCloud account status: restricted"

**Possible causes:**
- Screen Time restrictions
- Family Sharing limitations
- Corporate MDM policies

**Solution:**
- Check System Settings → Screen Time → Content & Privacy
- Contact your IT administrator if corporate device

## Monitoring Sync Activity

Watch for these log messages during operation:

```
[LandShip] 🔄 CloudKit sync: Remote change notification received
```

This indicates CloudKit is actively syncing changes from other devices.

## Testing Sync

1. **On iOS device:** Create a new vehicle or record
2. **Wait 10-30 seconds** (sync is not instant)
3. **On macOS:** Check if the new data appears
4. **Check Console.app** for sync notifications

## Still Not Working?

If you've completed all steps and sync still doesn't work on macOS:

1. **Capture detailed logs:**
   - Run with environment variables enabled
   - Save Console.app output filtered by "LandShip" and "CloudKit"

2. **Check CloudKit status page:**
   - https://www.apple.com/support/systemstatus/
   - Verify "iCloud Account & Sign In" and "CloudKit Database" are operational

3. **Test with a fresh container:**
   - Consider signing out of iCloud completely
   - Sign back in
   - Delete and reinstall the app

4. **File a bug with Apple:**
   - Use Feedback Assistant (https://feedbackassistant.apple.com)
   - Include Console logs and steps to reproduce
   - Reference FB number in your code for tracking

## Quick Reference: Console Commands

```bash
# Watch CloudKit logs in real-time
log stream --predicate 'process == "LandShip" OR subsystem CONTAINS "cloudkit"' --level debug

# Check last 30 minutes of CloudKit activity
log show --predicate 'process == "LandShip"' --last 30m --info

# Find CloudKit errors
log show --predicate 'subsystem CONTAINS "cloudkit"' --last 1h --level error
```

## Contact Information

If you need further assistance, the enhanced logging in the app will provide detailed diagnostic information when launched from Xcode.

---
**Last Updated:** February 22, 2026
**App Version:** Check AppInfo.swift for current version
**CloudKit Container:** iCloud.com.aeronauticaltrax.LandShip
