# Firebase Firestore Data Structure - Complete Guide

## Overview
Your smart socks app stores data in Firestore using a **hierarchical, user-centered structure**. Here's how it works:

---

## 📊 Complete Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    FIRESTORE DATABASE                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ├─── users (collection)
                              ├─── sensorReadings (collection)
                              ├─── riskScores (collection)
                              └─── Other collections...
```

---

## 🏗️ Detailed Structure

### 1️⃣ **Users Collection** 
**Path:** `users/{userId}`

**What stores here:** User profile information

**Data saved:**
```json
{
  "email": "user@example.com",
  "name": "John Doe",
  "age": 45,
  "diabetesType": "DiabetesType.type2",
  "diabetesYears": 5,
  "healthInfo": {
    "hasNeuropathy": true,
    "hasPAD": false,
    "hasPreviousUlcer": true,
    "hasHypertension": false
  },
  "settings": {
    "temperatureUnit": "celsius",
    "notificationsEnabled": true,
    "criticalAlertsEnabled": true
  },
  "createdAt": "2025-01-15T10:30:00Z",
  "updatedAt": "2025-02-04T14:22:00Z"
}
```

---

### 2️⃣ **Sensor Readings Collection**
**Path:** `sensorReadings/{userId}/readings/{timestamp}`

**What stores here:** ALL sensor data from smart socks (BOTH mock and real)

**Saved for EVERY reading (every 2 seconds):**
```json
{
  "timestamp": "2025-02-04T14:22:15Z",
  "temperatures": [31.5, 32.0, 31.0, 32.5],      // 4 zones: Heel, Ball, Arch, Toe
  "pressures": [35.0, 45.0, 20.0, 40.0],         // kPa
  "spO2": 98.0,                                  // Blood oxygen
  "heartRate": 72,                               // BPM
  "stepCount": 1250,                             // Total steps
  "activityType": "ActivityType.walking",        // Current activity
  "dataSource": "mock" or "real",                // Whether from mock or real BLE
  "maxTemperature": 32.5,
  "maxPressure": 45.0,
  "minTemperature": 31.0,
  "minPressure": 20.0
}
```

**Document ID:** Timestamp in milliseconds (e.g., `1738685535000`)
- Allows querying by time range
- Automatic sorting possible

---

### 3️⃣ **Risk Scores Collection**
**Path:** `riskScores/{userId}/scores/{timestamp}`

**What stores here:** ML predictions and foot ulcer risk analysis

**Saved for EVERY sensor reading (prediction happens every time):**
```json
{
  "timestamp": "2025-02-04T14:22:15Z",
  "overallScore": 35,                            // 0-100 risk score
  "riskLevel": "RiskLevel.moderate",             // low, moderate, high, critical
  "pressureRisk": 45,                            // Pressure-based risk
  "temperatureRisk": 31,                         // Temperature-based risk
  "circulationRisk": 0,                          // Circulation issues
  "gaitRisk": 0,                                 // Walking pattern risk
  "factors": ["High pressure in toe area", "Temperature spike"],  // Why it's risky
  "recommendations": ["Increase foot care frequency", "Monitor temperature"]  // What to do
}
```

---

### 4️⃣ **Alerts Collection**
**Path:** `alerts/{userId}/userAlerts/{auto-generated-id}`

**What stores here:** Critical alerts that need user attention

**Saved when:** Risk exceeds thresholds
```json
{
  "timestamp": "2025-02-04T14:25:00Z",
  "type": "AlertType.highPressure",
  "severity": "AlertSeverity.critical",
  "message": "Critical pressure detected on heel",
  "zone": "heel",
  "value": 95.0,
  "isResolved": false,
  "resolvedAt": null
}
```

---

## 🔄 Data Flow Diagram

```
Smart Socks (Hardware/Mock)
         │
         ▼
    BLE Service
    ├─ MockBleService (Test Data)
    └─ RealBleService (Real Hardware)
         │
         ▼
    SensorProvider
    (Receives reading every 2 seconds)
         │
         ├──────────────────────────┬──────────────────────────┐
         │                          │                          │
         ▼                          ▼                          ▼
    Sensor Reading          Risk Calculation          Local Storage
    (Raw Data)              (ML Prediction)          (Hive/Shared Pref)
         │                          │
         └──────────────┬───────────┘
                        │
                        ▼
                  Firestore Save
                        │
         ┌──────────────┼──────────────┐
         │              │              │
         ▼              ▼              ▼
  sensorReadings   riskScores     alerts
  (If critical)
```

---

## 📱 How Data Is Saved (Code Flow)

### When User Toggles Mock/Real Button:

```dart
// In sensor_provider.dart

void useRealBle(bool enable) {
  _useRealBle = enable;  // Toggle between services
}

// When streaming data:
if (_useRealBle) {
  // Use RealBleService → Real hardware readings
  await _realBleService.startStreaming();
} else {
  // Use MockBleService → Simulated test data
  await _mockBleService.startStreaming();
}

// Every reading received:
void _onReadingReceived(SensorReading reading) {
  
  // 1️⃣ Save raw sensor data to Firestore
  await _firestoreService.saveSensorReading(
    userId: userId,
    reading: reading
  );
  // Saves to: sensorReadings/{userId}/readings/{timestamp}
  
  // 2️⃣ Calculate risk and save prediction
  await _savePredictionToFirestore(reading);
  // Saves to: riskScores/{userId}/scores/{timestamp}
  
  // 3️⃣ Save locally
  await _storageService.saveReading(reading);
  // Saves to: Device storage (Hive)
}
```

---

## 🎯 Key Points

### ✅ What Gets Saved?

| Data | Frequency | Location |
|------|-----------|----------|
| **Sensor Readings** | Every 2 seconds | `sensorReadings/{userId}/readings/` |
| **Risk Predictions** | Every 2 seconds | `riskScores/{userId}/scores/` |
| **Critical Alerts** | When threshold exceeded | `alerts/{userId}/userAlerts/` |
| **User Profile** | On change | `users/{userId}` |

### ✅ Both Mock & Real Data

- **Mock Mode (ON)**: Generates random realistic data → Saves same way to Firestore
- **Real Mode (OFF)**: Gets actual Bluetooth data → Saves same way to Firestore
- **Same Collections**: Both data types go to identical Firestore structure

### ✅ Timestamp as Document ID

- Document ID = `timestamp.millisecondsSinceEpoch.toString()`
- Example: `1738685535000` (Feb 4, 2025, 14:22:15 UTC)
- **Benefit**: Automatic sorting, easy time-range queries

### ✅ Subcollections (User-Specific Data)

```
sensorReadings/{userId}/readings/{timestamp}  ← Readings are inside user's doc
riskScores/{userId}/scores/{timestamp}        ← Predictions are inside user's doc
alerts/{userId}/userAlerts/{auto-id}          ← Alerts are inside user's doc
```

---

## 📊 Query Examples

### Get Last 100 Readings:
```dart
final snapshot = await firestore
  .collection('sensorReadings')
  .doc(userId)
  .collection('readings')
  .orderBy('timestamp', descending: true)
  .limit(100)
  .get();
```

### Get Risk Scores from Last Hour:
```dart
final oneHourAgo = DateTime.now().subtract(Duration(hours: 1));
final snapshot = await firestore
  .collection('riskScores')
  .doc(userId)
  .collection('scores')
  .where('timestamp', isGreaterThan: oneHourAgo)
  .orderBy('timestamp', descending: true)
  .get();
```

### Get Critical Alerts:
```dart
final snapshot = await firestore
  .collection('alerts')
  .doc(userId)
  .collection('userAlerts')
  .where('severity', isEqualTo: 'AlertSeverity.critical')
  .where('isResolved', isEqualTo: false)
  .get();
```

---

## 💾 Storage Hierarchy Summary

```
Firestore (Cloud)
└── users/{userId}                          ← User Profile
└── sensorReadings/{userId}/readings        ← All sensor data
    └── {timestamp1}: {reading data}
    └── {timestamp2}: {reading data}
    └── {timestamp3}: {reading data}
└── riskScores/{userId}/scores              ← All risk predictions
    └── {timestamp1}: {risk data}
    └── {timestamp2}: {risk data}
    └── {timestamp3}: {risk data}
└── alerts/{userId}/userAlerts              ← Critical alerts
    └── {alertId1}: {alert data}
    └── {alertId2}: {alert data}
```

---

## 🔐 Security Rules (Recommended)

```firestore rules
match /sensorReadings/{userId}/readings/{document=**} {
  allow read, write: if request.auth.uid == userId;
}

match /riskScores/{userId}/scores/{document=**} {
  allow read, write: if request.auth.uid == userId;
}

match /alerts/{userId}/userAlerts/{document=**} {
  allow read, write: if request.auth.uid == userId;
}

match /users/{userId} {
  allow read, write: if request.auth.uid == userId;
}
```

---

## 📈 Data Growth Estimate

**Assuming 2-second reading interval:**

- **Per Hour**: 1,800 readings + 1,800 risk scores = 3,600 documents
- **Per Day**: 86,400 readings + 86,400 risk scores = 172,800 documents
- **Per Year**: ~63 million documents

**Storage**: ~2-3 GB per year (depending on field complexity)

---

## ✅ Your Current Setup

✔ Mock AND Real data → **Same Firestore location**  
✔ Auto-timestamped documents → **Easy sorting & queries**  
✔ User-specific collections → **Privacy & security**  
✔ Real-time predictions → **Risk calculated every reading**  
✔ Historical tracking → **All data preserved**

Everything is working correctly! 🎯
