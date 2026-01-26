# Pre-Publish Review & Checklist

I have reviewed your Customer App and Privacy Policy. I made several critical fixes to ensure your app is not rejected by the Play Store, but there are some **manual steps you must take** before uploading.

## ✅ Changes I Made (Fixed)

1.  **Android Permissions (`AndroidManifest.xml`)**:
    *   Added `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`. These were missing! Without them, your app would crash or fail to get location in Release mode.

2.  **iOS Configuration (`Info.plist`)**:
    *   Added missing usage descriptions for **Location**, **Camera**, and **Photo Library**. Even if you are focusing on Android, keep the codebase healthy.

3.  **Privacy Policy (`privacy-policy.html`)**:
    *   **SMS Permission**: Rephrased "SMS Read Permission" to "SMS Verification via SMS Retriever API". The previous wording sounded like you were reading *all* user messages, which triggers a high-risk declaration form on Play Console. The new wording is safer.
    *   **Location**: Clarified that location is collected "while using the app". This is important for the "Location in Background" declaration (you should answer **NO** to background location in Play Console).

4.  **Pubspec**: Updated the package description.

---

## 🚨 CRITICAL ACTIONS REQUIRED (Status Update)

### 1. ✅ Fix Signing Configuration (COMPLETED)
*   **Keystore**: Generated `upload-keystore.jks` in `android/app`.
*   **Properties**: Created `key.properties`.
*   **Gradle**: Updated `build.gradle.kts` to use the release key.

### 2. ✅ Update Grievance Officer Details (COMPLETED)
*   Updated `privacy-policy.html` with name "Rajikul Islam".

### 3. ✅ App Icon (COMPLETED)
*   Generated new icon and ran `flutter_launcher_icons`.

### 4. Play Console Declarations (Action Required)
When setting up your app in Google Play Console, answer the Data Safety form carefully:
*   **Location**: Yes, collected. Shared? Yes (with riders/vendors). Background? **NO**.
*   **Personal Info**: Name, Email, Phone, Address (Collected, App Functionality).
*   **Photos/Video**: Yes (if users upload profile pics).
*   **Files/Docs**: Yes (if users upload documents).
*   **Contacts**: **NO**.
*   **SMS**: **NO**.

### 5. ⚠️ Firebase Configuration (URGENT)
You **MUST** add these new fingerprints to Firebase for Google Sign-In and Phone Auth to work in production.

**Your Release Phase Keys:**

*   **SHA-1**: `B3:C2:97:47:81:4C:BF:8C:EC:37:DA:F9:06:77:72:0A:6A:8D:AC:81`
*   **SHA-256**: `AE:EB:C8:2C:A1:08:52:06:31:68:11:A1:B1:87:87:AA:DF:07:BC:01:5F:45:8B:3A:CA:81:10:E8:37:F3:9B:75`

**Steps:**
1.  Go to [Firebase Console](https://console.firebase.google.com/).
2.  Open **Project Settings** (Gear icon) > **General** > **Your Apps** > **Android App**.
3.  Click **Add fingerprint** and paste the **SHA-1** above.
4.  Click **Add fingerprint** again and paste the **SHA-256** above.
5.  (Optional) Download `google-services.json` and replace `android/app/google-services.json`.

---

## 🚀 ASSEMBLE RELEASE

1.  **Clean the project**:
    ```bash
    flutter clean
    flutter pub get
    ```

2.  **Build the App Bundle**:
    ```bash
    flutter build appbundle
    ```

3.  **Upload**:
    Upload the file `build/app/outputs/bundle/release/app-release.aab` to Google Play Console.

