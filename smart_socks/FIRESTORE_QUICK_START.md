# Quick Reference: Firestore Collections to Create

> **TLDR:** Create just the `users` collection. All subcollections are auto-created!

---

## ⚡ MINIMUM SETUP

### Step 1: Create One Collection
Go to **Firebase Console** > **Firestore Database** > **Create Collection**
- **Collection Name:** `users`
- Click **Next**
- **Document ID:** Leave empty (auto-created)
- **First Field:** Skip this (collections auto-create on first data save)

### Step 2: Update Security Rules
Go to **Firestore Database** > **Rules** and paste:

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

Click **Publish**

### Step 3: Done! ✅
Everything else auto-creates when you run the app.

---

## 📊 What Gets Auto-Created

When users use the app, these are created automatically:

```
users/{userId}/
├── readings/          (sensor data)
├── scores/            (risk calculations)
├── userAlerts/        (notifications)
├── dailySummaries/    (daily stats)
├── predictions/       (ML results)
├── tokens/            (push notifications)
├── activityLogs/      (user tracking)
└── healthMetrics/     (health stats)
```

---

## 🔍 Verify It's Working

1. **Run the app** and login/signup
2. **Edit profile** in Settings
3. **Open Firestore Console**
4. **Check:** `users` > `{your-uid}` > should see name, email, age updated
5. **Check:** `{your-uid}/tokens/fcm` should have FCM token
6. **Connect Bluetooth** and check `{your-uid}/readings/` for data

---

## ❌ Common Mistakes

| Mistake | Fix |
|---------|-----|
| Can't save profile | Check Security Rules are correct |
| Subcollections missing | They auto-create on first save - wait & refresh |
| Permission denied errors | Ensure Rules allow `request.auth.uid == userId` |
| Data not appearing | Check user is actually logged in first |

---

## 💡 Pro Tips

- Firestore is **case-sensitive** (users ≠ Users)
- Collections auto-delete when last document is deleted (normal)
- Timestamps are auto-managed by Firestore - you don't create them
- Each collection can have thousands of documents
- Max document size: 1 MB (plenty for sensor readings)

---

**Need help?** See full guide in `FIRESTORE_SETUP.md`
