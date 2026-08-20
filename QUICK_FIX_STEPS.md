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
