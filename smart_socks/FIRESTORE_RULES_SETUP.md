# 🔐 How to Fix Firestore Security Rules

## The Problem
Your Firestore is blocking all writes because security rules are not configured.

**Error:** `[cloud_firestore/permission-denied] Missing or insufficient permissions.`

---

## ✅ Solution: Apply Security Rules

### **Step 1: Go to Firebase Console**
1. Open https://console.firebase.google.com/
2. Select your project: `neurosocks-ai`
3. Go to **Firestore Database** (left menu)
4. Click **Rules** tab at the top

---

### **Step 2: Replace the Rules**
You'll see the default rules. **Replace them ALL** with this:

```firestore rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read/write their own user profile
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }

    // Allow authenticated users to read/write their own sensor readings
    match /sensorReadings/{userId}/readings/{document=**} {
      allow read, write: if request.auth.uid == userId;
    }

    // Allow authenticated users to read/write their own risk scores
    match /riskScores/{userId}/scores/{document=**} {
      allow read, write: if request.auth.uid == userId;
    }

    // Allow authenticated users to read/write their own alerts
    match /alerts/{userId}/userAlerts/{document=**} {
      allow read, write: if request.auth.uid == userId;
    }

    // Allow authenticated users to read/write their own daily summaries
    match /dailySummaries/{userId}/{document=**} {
      allow read, write: if request.auth.uid == userId;
    }

    // Allow authenticated users to read/write their own tokens
    match /tokens/{userId}/deviceTokens/{document=**} {
      allow read, write: if request.auth.uid == userId;
    }

    // Allow authenticated users to read/write their own notifications
    match /notifications/{userId}/{document=**} {
      allow read, write: if request.auth.uid == userId;
    }

    // Allow authenticated users to read/write their own activity logs
    match /activityLogs/{userId}/{document=**} {
      allow read, write: if request.auth.uid == userId;
    }

    // Allow authenticated users to read/write their own device data
    match /deviceData/{userId}/{document=**} {
      allow read, write: if request.auth.uid == userId;
    }

    // Allow authenticated users to read/write their own health metrics
    match /healthMetrics/{userId}/{document=**} {
      allow read, write: if request.auth.uid == userId;
    }

    // Allow authenticated users to read/write their own user settings
    match /userSettings/{userId}/{document=**} {
      allow read, write: if request.auth.uid == userId;
    }

    // Allow authenticated users to read/write their own reports
    match /reports/{userId}/{document=**} {
      allow read, write: if request.auth.uid == userId;
    }

    // Allow authenticated users to read/write their own predictions
    match /predictions/{userId}/{document=**} {
      allow read, write: if request.auth.uid == userId;
    }

    // Deny everything else by default
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

### **Step 3: Publish the Rules**
1. Click **Publish** button (bottom right)
2. Confirm the action
3. Wait for it to update (usually 1-2 minutes)

---

### **Step 4: Test**
1. Go back to your Flutter app
2. **Hot reload** the app (or restart)
3. Check the browser console

You should now see:
```
✅ Sensor reading saved successfully
✅ Risk prediction saved successfully
```

---

## 🔒 What These Rules Do

| Rule | Access |
|------|--------|
| `match /users/{userId}` | User can only access their own profile |
| `match /sensorReadings/{userId}/readings/{document=**}` | User can only access their own sensor readings |
| `match /riskScores/{userId}/scores/{document=**}` | User can only access their own risk scores |
| `match /alerts/{userId}/userAlerts/{document=**}` | User can only access their own alerts |
| All others | User can access only their own data (user-specific collections) |

**Key Security Feature:** `request.auth.uid == userId`
- This ensures users can ONLY read/write their OWN data
- Prevents users from accessing other users' data

---

## ✅ After Publishing Rules

Your data flow will be:
```
Mock/Real BLE → SensorProvider (has userId) → Firestore
                                    ↓
                    Firestore Rules Check:
                    Is user authenticated? ✅
                    Is userId the same? ✅
                    ALLOW WRITE ✅
```

---

## 🆘 If It Still Doesn't Work

1. **Check Rules are Published** - Look for green checkmark
2. **Check User is Logged In** - Console should show userId
3. **Check Browser Console** - For "✅ Saved successfully" messages
4. **Wait 2 Minutes** - Rules can take time to deploy

---

## 📝 Rule Deployment Time

Rules usually deploy within:
- **1-2 minutes** for most cases
- **Up to 5 minutes** in rare cases

You can check status in Firebase Console → Firestore → Rules tab

After deployment, all your sensor data will save automatically! 🚀
