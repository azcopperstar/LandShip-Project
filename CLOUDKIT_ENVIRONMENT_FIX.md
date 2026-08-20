# CloudKit Environment Fix - Development vs Production

## Problem Identified ✅

Your macOS app was syncing to **Development** CloudKit when run from Xcode, but **Production** CloudKit when installed from an archive. Since these are completely separate databases, data doesn't sync between them.

Your iOS devices are syncing to **Production** (from TestFlight/App Store), while your Mac was stuck on **Development** when running the installed build.

## Changes Made

### 1. Updated Entitlements (LandShip.entitlements)
Changed `aps-environment` from `development` to `production`:
```xml
<key>aps-environment</key>
<string>production</string>
```

### 2. Added Environment Detection (LandShipApp.swift)
The app now logs which CloudKit environment it's using:
- `🌐 CloudKit Environment: PRODUCTION` - Good for archived builds
- `🌐 CloudKit Environment: DEVELOPMENT (Xcode)` - When running from Xcode

## Fix Steps - Choose Your Approach

### Option A: Use Production for Everything (Recommended)

This makes all builds (Xcode and archived) use the **Production** environment, matching your iOS devices.

**Steps:**

1. ✅ **Entitlements already updated** to `production`

2. **Deploy Development Schema to Production:**
   - Go to https://icloud.developer.apple.com/dashboard
   - Sign in with your Apple Developer account
   - Select **"CloudKit Database"**
   - Choose **"iCloud.com.aeronauticaltrax.LandShip"** container
   - Switch to **Development** environment (top dropdown)
   - Click **"Deploy Schema Changes"**
   - Select **"Deploy to Production"**
   - Confirm the deployment

3. **Clear Development Cache on macOS:**
   ```bash
   # Quit LandShip completely first!

   # Clear app caches
   rm -rf ~/Library/Caches/com.aeronauticaltrax.LandShip

   # Clear CloudKit development cache
   rm -rf ~/Library/Application\ Support/CloudKit/iCloud.com.aeronauticaltrax.LandShip

   # Clear app containers (will re-sync from production)
   rm -rf ~/Library/Containers/com.aeronauticaltrax.LandShip
   ```

4. **Restart your Mac** (recommended)

5. **Archive and Install** the app (don't run from Xcode yet)

6. **Launch and verify:**
   - Check Console.app for: `🌐 CloudKit Environment: PRODUCTION`
   - Data should sync with iOS devices

7. **For Xcode Development:**
   - When running from Xcode, it will still try to use Development
   - To force Production even in Xcode, add this to your scheme:
     - Edit Scheme → Run → Options
     - Uncheck "Use the Run button's build configuration"

### Option B: Use Development in Xcode, Production for Archives

Keep Development environment for Xcode testing, Production for released builds.

**Steps:**

1. **Revert entitlements to development:**
   ```bash
   # Edit LandShip/LandShip.entitlements
   # Change aps-environment back to "development"
   ```

2. **Create a separate Release entitlements file:**
   - Duplicate `LandShip.entitlements` as `LandShip-Release.entitlements`
   - In the Release version, set `aps-environment` to `production`

3. **Update Xcode build settings:**
   - Select your project in Xcode
   - Select the LandShip target
   - Go to "Build Settings"
   - Find "Code Signing Entitlements"
   - For Debug: `LandShip/LandShip.entitlements`
   - For Release: `LandShip/LandShip-Release.entitlements`

4. **Deploy schema to production** (same as Option A, step 2)

5. **Clear caches** (same as Option A, step 3)

## Verification Steps

After implementing either option:

1. **Run from Xcode** (Cmd+R):
   ```bash
   # Open Terminal and watch logs:
   log stream --predicate 'process == "LandShip"' --level debug
   ```
   Look for: `🌐 CloudKit Environment: DEVELOPMENT (Xcode)` or `PRODUCTION`

2. **Archive and Install**:
   - Product → Archive
   - Distribute App → Copy App
   - Install on your Mac
   - Launch and check logs
   - Should see: `🌐 CloudKit Environment: PRODUCTION`

3. **Test Sync**:
   - Add a vehicle on iOS device
   - Wait 30 seconds
   - Should appear on macOS
   - Check logs for: `🔄 CloudKit sync: Remote change notification received`

## Understanding CloudKit Environments

### Development Environment
- **Purpose:** Testing and development
- **Used by:** Apps run from Xcode, development builds
- **Data:** Separate from production, can be reset
- **Schema:** Can be modified freely

### Production Environment
- **Purpose:** Released apps (App Store, TestFlight)
- **Used by:** Archived builds, distributed apps
- **Data:** Persistent, shared by all users
- **Schema:** Requires deployment from Development, cannot be easily changed

## Common Issues After Fixing

### Issue: "No data appears after switching to production"
**Cause:** Production database is empty (all data was in Development)

**Solutions:**
1. Accept the fresh start and enter data on production
2. Manually migrate data:
   - Export from Development using your backup feature
   - Import to Production build

### Issue: "Schema mismatch errors"
**Cause:** Production schema not deployed

**Solution:**
- Deploy Development schema to Production in CloudKit Dashboard
- Wait a few minutes for propagation
- Restart the app

### Issue: "Still seeing Development environment after changes"
**Cause:** Cached build or entitlements not updated

**Solution:**
```bash
# Clean build folder
rm -rf ~/Library/Developer/Xcode/DerivedData

# In Xcode: Product → Clean Build Folder (Cmd+Shift+K)

# Rebuild completely
```

## Monitoring CloudKit Sync

The app now includes detailed logging. Watch for these messages:

```
[LandShip] 🌐 CloudKit Environment: PRODUCTION
[LandShip] ✅ iCloud account status: available
[LandShip] ✅ Successfully created CloudKit-backed container
[LandShip] Store mode: CloudKit-backed
[LandShip] 🔄 CloudKit sync: Remote change notification received
```

## CloudKit Dashboard - Checking Your Data

1. Go to https://icloud.developer.apple.com/dashboard
2. Select "CloudKit Database"
3. Choose your container: "iCloud.com.aeronauticaltrax.LandShip"
4. Switch between Development/Production environments
5. Click "Records" to see your data
6. Search for record types: Vehicle8, ServiceRecords1, FuelLog1, etc.

## Recommended Workflow Going Forward

**For Development:**
- Use Development environment from Xcode
- Test new features safely
- Schema changes won't affect production

**For Release:**
1. Test thoroughly in Development
2. Deploy schema to Production in CloudKit Dashboard
3. Archive with production entitlements
4. Test archived build before distributing
5. Distribute via TestFlight or direct install

## Quick Commands Reference

```bash
# Watch CloudKit logs in real-time
log stream --predicate 'process == "LandShip" OR subsystem CONTAINS "cloudkit"' --level debug

# Check which environment an installed app uses
strings /Applications/LandShip.app/Contents/embedded.mobileprovision | grep aps-environment

# Clear all CloudKit caches
rm -rf ~/Library/Application\ Support/CloudKit
rm -rf ~/Library/Caches/CloudKit

# Reset LandShip completely
rm -rf ~/Library/Containers/com.aeronauticaltrax.LandShip
rm -rf ~/Library/Caches/com.aeronauticaltrax.LandShip
```

## Support

If you continue to have sync issues:

1. Check the logs for the exact environment being used
2. Verify schema is deployed to production
3. Confirm all devices use the same Apple ID
4. Check https://www.apple.com/support/systemstatus/ for CloudKit outages

---
**Last Updated:** February 22, 2026
**Files Modified:**
- `LandShip/LandShip.entitlements` - Changed to production
- `LandShip/0 Main/1 LandShipApp.swift` - Added environment detection
