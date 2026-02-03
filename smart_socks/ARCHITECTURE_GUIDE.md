# 📊 Complete Architecture & Data Flow Guide

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SMART SOCKS HARDWARE                     │
│  Temperature Sensors | Pressure Sensors | IMU Sensors       │
│  Foot Zones: Heel, Ball, Arch, Toe (4-9 zones)             │
└──────────────────────┬──────────────────────────────────────┘
                       │
                   Bluetooth LE
                   (flutter_blue_plus)
                       │
┌──────────────────────┴──────────────────────────────────────┐
│              REAL BLE SERVICE (Device Layer)               │
│  - Discover devices                                        │
│  - Connect/disconnect                                      │
│  - Read sensor characteristics                             │
│  - Stream continuous data                                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
            SensorReading (Model)
            └─ timestamp, temperatures[], pressures[]
              spO2, heartRate, stepCount, batteryLevel
                       │
┌──────────────────────┴──────────────────────────────────────┐
│          SENSOR PROVIDER (State Management)                 │
│  - Manage BLE connection status                            │
│  - Buffer recent readings (last 100)                       │
│  - Calculate foot data (left/right)                        │
│  - Calculate trends                                        │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
   ┌────────┐    ┌──────────┐   ┌──────────┐
   │ Hive   │    │ Firestore│   │ Risk     │
   │ Local  │    │ Cloud    │   │ Provider │
   │ DB     │    │ Database │   │ (ML)     │
   └────────┘    └──────────┘   └──────────┘
        │              │              │
        │     ┌────────┴──────────┐   │
        │     │                   │   │
        ▼     ▼                   ▼   ▼
    ┌─────────────────────────────────────┐
    │   FIREBASE FIRESTORE COLLECTIONS    │
    │                                     │
    │  users/{userId}/                   │
    │  ├── readings/                     │
    │  ├── scores/                       │
    │  ├── userAlerts/                   │
    │  ├── dailySummaries/               │
    │  ├── predictions/                  │
    │  ├── tokens/                       │
    │  └── activityLogs/                 │
    └─────────────────────────────────────┘
        │
        ▼
    ┌─────────────────────────┐
    │  USER INTERFACE LAYERS  │
    │                         │
    │  Dashboard              │
    │  ├─ Risk Gauge          │
    │  ├─ Temperature Graph   │
    │  └─ Alert History       │
    │                         │
    │  Sensors Screen         │
    │  ├─ Real-time Data      │
    │  ├─ Foot Heatmap        │
    │  └─ Zone Analysis       │
    │                         │
    │  Alerts Screen          │
    │  ├─ Alert List          │
    │  └─ Risk Timeline       │
    │                         │
    │  Settings Screen        │
    │  ├─ Edit Profile        │
    │  ├─ Device Connection   │
    │  └─ Preferences         │
    └─────────────────────────┘
```

---

## 🔄 Data Flow Diagrams

### Flow 1: Bluetooth Reading Arrives

```
Hardware sends data
        │
        ▼
RealBleService._readCharacteristic()
        │
        ▼
Parse bytes → SensorReading object
        │
        ▼
Emit via StreamController
        │
        ▼
SensorProvider._onReadingReceived()
        │
        ├─ 1. Update UI state
        │   └─ _currentReading = reading
        │
        ├─ 2. Save to Hive (IMMEDIATELY)
        │   └─ await _storageService.saveReading(reading)
        │
        ├─ 3. Save to Firestore (ASYNC, no wait)
        │   └─ _firestoreService.saveSensorReading(...)
        │       └─ users/{uid}/readings/{timestamp}
        │
        ├─ 4. Calculate risk score
        │   └─ RiskCalculator.calculate(reading)
        │
        ├─ 5. Save risk to Firestore
        │   └─ _firestoreService.saveRiskScore(...)
        │       └─ users/{uid}/scores/{timestamp}
        │
        └─ 6. Calculate ML prediction
            └─ FootUlcerPredictionService.predictRisk()
                └─ _firestoreService (predictions/)
                   └─ users/{uid}/predictions/{timestamp}
        │
        ▼
Dashboard updates (showsreal-time temp/pressure)
        │
        ▼
Users see live data!
```

### Flow 2: Profile Edit

```
Settings Screen UI
        │
        ▼
User clicks "Edit Profile"
        │
        ▼
Dialog shows with current values
        │
        ▼
User changes fields (name, age, etc)
        │
        ▼
User clicks "Save Changes"
        │
        ▼
await provider.updateProfile(...)
        │
        ▼
UserProvider.updateProfile()
        │
        ├─ 1. Validate user profile exists
        │
        ├─ 2. Create updated profile object
        │   └─ _userProfile = _userProfile.copyWith(...)
        │
        ├─ 3. Save to Hive (local DB)
        │   └─ await _storageService.saveUserProfile(...)
        │
        └─ 4. Save to Firestore (cloud)
            └─ await _firestoreService.saveUserProfile(...)
                └─ users/{uid} document updated
                   ├─ name: "new name"
                   ├─ age: 45
                   ├─ phone: "+1234567890"
                   └─ updatedAt: timestamp
        │
        ▼
Firestore returns (await resolves)
        │
        ▼
Show success snackbar
        │
        ▼
Close dialog
        │
        ▼
Settings screen refreshes with new data
```

### Flow 3: User Authentication

```
Sign Up / Login Screen
        │
        ▼
User enters email + password
        │
        ▼
FirebaseAuthProvider.login() / signUp()
        │
        ├─ Firebase Auth validates credentials
        │  └─ Creates user in Firebase Auth
        │
        ▼
User created → get UID (e.g., abc123xyz)
        │
        ├─ 1. Save to Firebase Auth
        │
        ├─ 2. Create profile in Firestore
        │   └─ users/{abc123xyz} document created
        │       ├─ email: user@example.com
        │       ├─ name: "John Doe"
        │       ├─ age: 45
        │       └─ diabetesType: "type2"
        │
        └─ 3. Get FCM token & save
            └─ FirebaseMessagingService.initialize()
                └─ _firestoreService.saveFCMToken(...)
                   └─ users/{abc123xyz}/tokens/fcm
                       ├─ token: "fcm...token...string"
                       ├─ deviceName: "Samsung Galaxy S21"
                       └─ updatedAt: timestamp
        │
        ▼
Dashboard initializes
        │
        ├─ UserProvider.syncFromFirestore(uid)
        │  └─ Loads profile from users/{uid}
        │
        ├─ SensorProvider.setCurrentUser(uid)
        │  └─ Enables Firestore saving for sensor data
        │
        └─ SensorProvider.connect()
           └─ Connects to Bluetooth device
        │
        ▼
Streams start:
  - Sensor data stream
  - Risk score stream
  - Alert stream
        │
        ▼
Real-time monitoring active!
```

---

## 📈 Firestore Data Size Estimates

| Collection | Documents/Year | Size | Notes |
|------------|----------------|------|-------|
| readings | 315,360 (2 min intervals, 24h) | ~150 MB | Largest collection |
| scores | 315,360 | ~50 MB | Same frequency as readings |
| userAlerts | 50-200 | ~0.5 MB | Only on threshold breach |
| dailySummaries | 365 | ~0.05 MB | One per day |
| predictions | 315,360 | ~80 MB | With every risk calc |
| tokens | 1-5 | <0.01 MB | Minimal |
| activityLogs | 10-50 | ~0.1 MB | Login/logout/profile |
| **TOTAL** | **630,000+** | **~280 MB/year** | ~0.77 MB/day |

**Cost Estimate (Firestore pricing Jan 2026):**
- Reads: ~630K/year ≈ $3.15
- Writes: ~630K/year ≈ $3.15
- Storage: ~280 MB ≈ $0.06/month
- **Total: ~$7-10/year for one active user**

---

## 🔐 Security Model

```
Firebase Auth (Authentication)
├─ Email/Password signup
├─ Sign in
├─ Password reset
├─ Account deletion
└─ UID generation (abc123xyz)

Firestore Rules (Authorization)
├─ User can READ own data
│  └─ ALLOW: request.auth.uid == userId
│
├─ User can WRITE own data
│  └─ ALLOW: request.auth.uid == userId
│
└─ User CANNOT access others' data
   └─ DENY: all other users

Subcollections inherit parent rules
└─ If you can access users/{uid},
   you can access users/{uid}/readings, etc.

Result: Complete data isolation per user ✅
```

---

## 🚀 Performance Optimizations

### Local-First Strategy
```
When reading sensor data:
1. Check Hive (local) first → instant response ⚡
2. Background sync to Firestore (no blocking) 🔄
3. If offline, still works from local storage 📱

Result: Smooth UI, automatic cloud backup
```

### Batch Writing
```
Option: Instead of 1 write per reading:

Current: ~315,000 writes/year ✅

Could be: Batch every 10 readings
└─ ~31,500 writes/year (10x cheaper)

Trade-off: Slight delay before cloud sync
Benefit: 10x cost reduction
```

### Data Retention
```
Keep in Firestore: All historical data
└─ Useful for ML model training

Archive annually: Move old data to Cloud Storage
└─ 100 MB/year = cheap long-term storage

Keep in Hive: Only last 100 readings
└─ Fast local access to recent data
```

---

## 📱 Platform-Specific Notes

### Android
```
✅ Real Bluetooth: flutter_blue_plus works perfectly
✅ FCM: Firebase Cloud Messaging works natively
✅ Background sync: Can run in background
✅ Firestore: Full support

Permissions needed (AndroidManifest.xml):
- BLUETOOTH_SCAN
- BLUETOOTH_CONNECT
- ACCESS_FINE_LOCATION (for BLE scanning)
- INTERNET
- INTERNET_PERMISSION
```

### iOS
```
✅ Real Bluetooth: flutter_blue_plus works perfectly
✅ FCM: Firebase Cloud Messaging works natively
✅ Background sync: Limited by iOS restrictions
✅ Firestore: Full support

Permissions needed (Info.plist):
- NSBluetoothPeripheralUsageDescription
- NSLocationWhenInUseUsageDescription
- NSLocalNetworkUsageDescription
```

---

## 🛠️ Development vs Production

### Development Mode
```
✅ Full logging enabled
✅ Relaxed Firestore rules (optional)
✅ Mock data for testing (in /lib/data/services/mock_*)
✅ Debug console output

// In code:
debugPrint('...');  // Shows in console
```

### Production Mode
```
✅ Strict Firestore rules (users can only access their data)
✅ Mock data DISABLED (only real Bluetooth)
✅ Error logging to Crashlytics
✅ Optimized bundle size

// In code:
_useRealBle = true;  // Force real BLE
```

---

## 🎯 Key Metrics to Monitor

```
Dashboard Metrics:
├─ Connection Status: "Connected" / "Disconnected"
├─ Data Points/Day: Target 720 (1 per 2 minutes)
├─ Firestore Latency: <2 seconds typical
├─ Battery Usage: Monitor smart socks battery %
├─ App Memory: <150 MB typical
└─ CPU Usage: <20% during streaming

Firebase Metrics:
├─ Read Latency: <100ms
├─ Write Latency: <500ms
├─ Error Rate: <1%
└─ Data Transfer: 0.77 MB/day typical

User Metrics:
├─ Session Duration: Average hours using app
├─ Alert Frequency: High = more health monitoring
├─ Risk Score Trend: Should be stable or improving
└─ Device Pairing: Usually 1 device per user
```

---

## 🎓 Learning Resources

- **Flutter Provider Pattern:** https://pub.dev/packages/provider
- **Firebase Firestore:** https://firebase.google.com/docs/firestore
- **Flutter Blue Plus:** https://pub.dev/packages/flutter_blue_plus
- **Dart Async/Await:** https://dart.dev/guides/language/language-tour

---

## 📞 Troubleshooting Quick Links

| Problem | Solution |
|---------|----------|
| Data not saving | Check Firestore rules |
| Bluetooth not connecting | Ensure permissions granted |
| Profile edit not updating | Check user ID is not empty |
| Firestore permission denied | Update security rules |
| App crashes | Check console logs in Android Studio |
| Data missing from Firestore | Check if user is authenticated |

---

**Status: ✅ COMPLETE AND PRODUCTION-READY**

All systems integrated, tested, and documented. Ready for deployment! 🚀
