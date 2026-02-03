# Firestore Collections Summary

## 🎯 What You Need to Create

### ONLY Create This (Everything Else Auto-Creates)

```
Firestore Database
└── users (CREATE THIS COLLECTION)
    └── (Documents auto-create when user signs up)
```

That's it! 🎉

---

## 📚 What Auto-Creates When App Runs

When users sign up and use the app, these subcollections automatically appear:

| Subcollection | Purpose | Auto-Created When |
|----------------|---------|-------------------|
| `readings/` | Sensor temperature & pressure data | Bluetooth data arrives |
| `scores/` | Risk score calculations | After each sensor reading |
| `userAlerts/` | Alert notifications | Risk threshold exceeded |
| `dailySummaries/` | Daily statistics | Daily sync (auto) |
| `predictions/` | ML ulcer risk predictions | After risk calculation |
| `tokens/` | FCM push notification tokens | User logs in |
| `activityLogs/` | User activity tracking | Login/logout/profile update |
| `healthMetrics/` | Health aggregations | Health data collected |

---

## 🔐 Security Rules (REQUIRED)

Copy this to Firebase Console > Firestore > Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
      
      match /{document=**} {
        allow read, write: if request.auth.uid == userId;
      }
    }
    
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## ✅ That's All You Need!

The app will handle everything else automatically. When you:

1. **Sign Up** → `users/{uid}` created
2. **Edit Profile** → `users/{uid}` fields updated
3. **Connect Bluetooth** → `users/{uid}/readings/` starts populating
4. **Get Alerts** → `users/{uid}/userAlerts/` gets documents
5. **Device pairs** → `users/{uid}/tokens/fcm` created

---

## 🚀 Quick Checklist

- [ ] Create `users` collection in Firestore
- [ ] Update Security Rules (copy from above)
- [ ] Click "Publish"
- [ ] Run the app
- [ ] Sign up / Login
- [ ] Check Firestore console - data should appear!

Done! ✅
