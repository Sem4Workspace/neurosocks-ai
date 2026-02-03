# Firestore Database Setup Guide

**For:** Smart Socks IoT App  
**Last Updated:** February 3, 2026

---

## 📋 Required Firestore Collections & Subcollections

This guide shows you exactly what collections and subcollections you need to create in your Firebase Firestore database.

### Root Collections

These are the **top-level** collections you need to create:

#### 1. **`users`** (Required - Stores user profiles)
```
users/
  └── {userId}
        ├── email: string
        ├── name: string
        ├── age: number
        ├── diabetesType: string
        ├── diabetesYears: number
        ├── phone: string
        ├── emergencyContactName: string
        ├── emergencyContactPhone: string
        ├── photoUrl: string
        ├── createdAt: timestamp
        ├── updatedAt: timestamp
        ├── lastLoginAt: timestamp
        ├── settings: {
        │     temperatureUnit: string (celsius|fahrenheit)
        │     notificationsEnabled: boolean
        │     criticalAlertsEnabled: boolean
        │     themeMode: string (system|light|dark)
        │   }
        ├── healthInfo: {
        │     hasNeuropathy: boolean
        │     hasPAD: boolean
        │     hasPreviousUlcer: boolean
        │     hasHypertension: boolean
        │   }
        │
        ├── Subcollection: **`readings`** (Sensor data)
        │   └── {timestamp}
        │         ├── timestamp: timestamp
        │         ├── temperatures: array<number>
        │         ├── pressures: array<number>
        │         ├── spO2: number
        │         ├── heartRate: number
        │         ├── stepCount: number
        │         ├── batteryLevel: number
        │         └── activityType: string
        │
        ├── Subcollection: **`scores`** (Risk scores)
        │   └── {timestamp}
        │         ├── timestamp: timestamp
        │         ├── overallScore: number
        │         ├── riskLevel: string (low|moderate|high|critical)
        │         ├── pressureRisk: number
        │         ├── temperatureRisk: number
        │         ├── circulationRisk: number
        │         ├── gaitRisk: number
        │         ├── factors: array<string>
        │         └── recommendations: array<string>
        │
        ├── Subcollection: **`userAlerts`** (Alert notifications)
        │   └── {autoId}
        │         ├── type: string (temperature|pressure|risk|system)
        │         ├── severity: string (info|warning|critical)
        │         ├── message: string
        │         ├── location: string (heel|ball|arch|toe)
        │         ├── timestamp: timestamp
        │         ├── read: boolean
        │         └── data: map (any additional data)
        │
        ├── Subcollection: **`dailySummaries`** (Aggregated daily stats)
        │   └── {YYYY-MM-DD}
        │         ├── date: string
        │         ├── avgTemperature: number
        │         ├── maxTemperature: number
        │         ├── avgPressure: number
        │         ├── maxPressure: number
        │         ├── alertCount: number
        │         ├── riskLevel: string
        │         ├── stepCount: number
        │         ├── avgHeartRate: number
        │         └── readingCount: number
        │
        ├── Subcollection: **`tokens`** (FCM push notification tokens)
        │   └── fcm
        │         ├── token: string
        │         ├── deviceName: string
        │         ├── platform: string (ios|android|web)
        │         └── updatedAt: timestamp
        │
        ├── Subcollection: **`activityLogs`** (User activity tracking)
        │   └── {autoId}
        │         ├── type: string (login|logout|profile_update|device_connected)
        │         ├── timestamp: timestamp
        │         └── details: map
        │
        ├── Subcollection: **`healthMetrics`** (Weekly/monthly aggregates)
        │   └── {metricName}
        │         ├── name: string
        │         ├── value: number
        │         ├── unit: string
        │         ├── period: string (daily|weekly|monthly)
        │         └── timestamp: timestamp
        │
        └── Subcollection: **`predictions`** (ML ulcer risk predictions)
            └── {timestamp}
                  ├── timestamp: timestamp
                  ├── riskScore: number (0-100)
                  ├── riskLevel: string (low|moderate|high|critical)
                  ├── affectedZone: string
                  ├── riskFactors: array<string>
                  └── recommendation: string
```

---

## 🚀 Quick Setup Steps

### Step 1: Create Root Collection `users`
1. Go to **Firebase Console** > **Firestore Database**
2. Click **Create Collection**
3. Name it: `users`
4. Add a test document (or leave empty - Firebase will create it automatically on first save)

### Step 2: Manual (Optional - Auto-created)
The following collections are **automatically created** when your app saves data:
- `users/{userId}/readings`
- `users/{userId}/scores`
- `users/{userId}/userAlerts`
- `users/{userId}/dailySummaries`
- `users/{userId}/tokens`
- `users/{userId}/activityLogs`
- `users/{userId}/healthMetrics`
- `users/{userId}/predictions`

### Step 3: Firestore Security Rules

Copy these security rules to **Firestore Database > Rules**:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
      
      // Allow reading own subcollections
      match /{document=**} {
        allow read, write: if request.auth.uid == userId;
      }
    }
    
    // Deny access to other users' data
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## 📊 Data Flow Diagrams

### Sensor Data Flow
```
Smart Socks (Hardware)
    ↓
BLE Receiver (Real BLE Service)
    ↓
SensorProvider (In-Memory)
    ↓
Local Storage (Hive Database)
    ↓
Firestore (Cloud Backup)
    ├── users/{userId}/readings
    ├── users/{userId}/scores
    ├── users/{userId}/dailySummaries
    └── users/{userId}/predictions
```

### Profile Update Flow
```
Settings Screen (UI)
    ↓
UserProvider (Edit Profile Dialog)
    ↓
updateProfile() method
    ├── Local Storage (Hive)
    └── Firestore (users/{userId})
        ├── Save profile data
        └── Update timestamp
```

### Authentication Flow
```
Login/Sign Up Screen
    ↓
FirebaseAuthProvider (login/signUp)
    ↓
Firebase Auth (Create/Authenticate User)
    ↓
Save Profile to Firestore (users/{userId})
    ├── User Info
    ├── Health Data
    └── Settings
    ↓
Save FCM Token (users/{userId}/tokens/fcm)
    └── Enable Push Notifications
```

---

## 🔍 Collection Details

### `users/{userId}/readings` (Sensor Readings)
- **Purpose:** Store raw sensor data from smart socks
- **Document Key:** Timestamp in milliseconds (e.g., `1707000000000`)
- **Auto-saved:** When Bluetooth data arrives
- **Retention:** Keep all for historical analysis
- **Query:** Get last 100 readings for graphs

### `users/{userId}/scores` (Risk Scores)
- **Purpose:** Store calculated risk assessments
- **Document Key:** Timestamp in milliseconds
- **Auto-saved:** After each sensor reading (with risk calculation)
- **Use:** Show risk gauge, trends, alerts

### `users/{userId}/userAlerts` (Alerts)
- **Purpose:** Log all alerts triggered
- **Document Key:** Auto-generated (Firestore creates ID)
- **Saved:** When risk threshold exceeded
- **Use:** Show alert history, send push notifications

### `users/{userId}/dailySummaries` (Daily Stats)
- **Purpose:** Aggregate daily statistics
- **Document Key:** Date string `YYYY-MM-DD`
- **Manual save:** Once per day (can be scheduled)
- **Use:** Show daily overview, weekly trends

### `users/{userId}/tokens` (FCM Tokens)
- **Purpose:** Store device push notification tokens
- **Document Key:** `fcm` (single document)
- **Auto-saved:** When app initializes & token refreshes
- **Use:** Send push notifications for alerts

### `users/{userId}/activityLogs` (User Activity)
- **Purpose:** Track user actions for analytics
- **Document Key:** Auto-generated
- **Manual save:** login, logout, profile updates
- **Use:** Analytics, usage patterns

### `users/{userId}/predictions` (ML Predictions)
- **Purpose:** Store foot ulcer risk predictions
- **Document Key:** Timestamp in milliseconds
- **Auto-saved:** With each risk calculation
- **Use:** Historical ML model performance, trends

---

## 💾 Data Sizes & Indexing

| Collection | Est. Documents/Year | Size | Indexing |
|------------|-------------------|------|----------|
| readings | 315,360 (2 min intervals) | ~150 MB | Index on userId + timestamp |
| scores | 315,360 | ~50 MB | Index on userId + timestamp |
| userAlerts | 50-100 | ~0.5 MB | Index on userId + timestamp |
| dailySummaries | 365 | ~0.05 MB | No indexing needed |
| predictions | 315,360 | ~80 MB | Index on userId + timestamp |

**Tip:** Create composite indexes in Firestore for queries like:
- `users/{userId}/readings` sorted by `timestamp DESC` with limit

---

## ✅ Verification Checklist

- [ ] Created `users` root collection
- [ ] Set up Firestore security rules
- [ ] FCM token saving working (check `users/{userId}/tokens`)
- [ ] Sensor data saved to `users/{userId}/readings`
- [ ] Risk scores saved to `users/{userId}/scores`
- [ ] Profile edits sync to `users/{userId}`
- [ ] Daily summaries creating documents with correct date keys
- [ ] Alerts storing in `users/{userId}/userAlerts`
- [ ] Activity logs recording user actions

---

## 🔧 Troubleshooting

### Issue: "Permission denied" errors
**Solution:** Check Firestore rules allow user's UID and document path

### Issue: Data not saving to Firestore
**Solution:** 
1. Check user is logged in (`context.read<FirebaseAuthProvider>().isLoggedIn`)
2. Verify collection names match exactly (case-sensitive)
3. Check network connectivity
4. Review Firebase console for errors

### Issue: Subcollections not appearing
**Solution:** Collections are created automatically when you save first document. Check console.log for save errors.

---

## 📝 Example Queries (from code)

```dart
// Get user profile
await _firestoreService.getUserProfile(userId);

// Get sensor readings (last 100)
await _firestoreService.getSensorReadings(userId: userId, limit: 100);

// Get latest risk score
await _firestoreService.getLatestRiskScore(userId);

// Get alerts (last 50)
await _firestoreService.getAlerts(userId: userId, limit: 50);

// Stream alerts in real-time
_firestoreService.alertsStream(userId);

// Save daily summary
await _firestoreService.saveDailySummary(
  userId: userId,
  summaryData: {
    'date': '2026-02-03',
    'avgTemperature': 31.5,
    'readingCount': 720,
  },
);

// Save FCM token
await _firestoreService.saveFCMToken(
  userId: userId,
  fcmToken: 'fcm-token-string',
);
```

---

## 🎯 Next Steps

1. **Create the `users` collection in Firestore** (other subcollections auto-create)
2. **Update Firestore Rules** (use the rules above)
3. **Test profile saving** in Settings > Edit Profile
4. **Verify sensor data** appears in Firestore readings collection
5. **Monitor Firestore** console to see data flowing in

---

**Questions?** Check the code comments in:
- `lib/data/services/firebase/firebase_firestore_service.dart`
- `lib/providers/user_provider.dart`
- `lib/providers/sensor_provider.dart`
