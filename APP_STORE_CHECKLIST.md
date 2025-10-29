# HushMap App Store Submission Checklist

## ⚠️ CRITICAL - Must Fix Before Submission

### 1. Privacy Policy & Terms of Service
**Status:** ❌ **MISSING - REQUIRED**

Apple **requires** a privacy policy URL for apps that:
- Collect location data ✓ (you do)
- Use health data ✓ (Watch app uses HealthKit)
- Have user accounts ✓ (Google/Apple Sign-In)
- Use third-party services ✓ (Google Maps, OpenAI)

**What you need:**
- Host privacy policy online (can be on GitHub Pages, your website, etc.)
- Add link in App Store Connect during submission
- Optionally add to AboutView in the app

**Minimum privacy policy must cover:**
- What data you collect (location, health, user profiles)
- How you use it (maps, AI predictions, reports)
- Third-party services (Google Maps, OpenAI, Firebase if used)
- Data retention and deletion
- User rights (GDPR compliance)

### 2. Account Deletion
**Status:** ❌ **MISSING - REQUIRED for apps with accounts**

Apple requires apps with account creation to provide **in-app account deletion**.

**Current issue:** You have Google/Apple Sign-In but no delete account option.

**Fix needed in ProfileView:**
- Add "Delete Account" button
- Implement account deletion flow
- Delete all user data (reports, profile, etc.)
- Show confirmation dialog

### 3. API Keys Security
**Status:** ⚠️ **EXPOSED IN INFO.PLIST**

Your API keys are visible in Info.plist:
```xml
<key>GOOGLE_MAPS_API_KEY</key>
<string>$(GOOGLE_MAPS_API_KEY)</string>
```

**Recommendations:**
- ✅ Good: Using build config variables
- ⚠️ Consider: Move to backend API for production
- ⚠️ Add API key restrictions in Google Cloud Console
- ⚠️ Add OpenAI usage limits/monitoring

---

## ✅ App Store Requirements - Present

### Required Metadata
- ✅ App name: HushMap
- ✅ Bundle ID configured
- ✅ Version number present
- ✅ App icon (iOS & Watch)
- ✅ Privacy descriptions in Info.plist

### Permissions (Well Documented)
- ✅ Location: "HushMap needs your location to show nearby quiet places..."
- ✅ Microphone: "HushMap uses your microphone to measure ambient noise levels..."
- ✅ Speech Recognition: "HushMap uses speech recognition to convert..."
- ✅ Health (Watch): "HushMap uses environmental sound levels..."

### Core Functionality
- ✅ Map view with reports
- ✅ Add reports
- ✅ User authentication (Google/Apple)
- ✅ Anonymous mode
- ✅ Watch app with sync
- ✅ Accessibility features
- ✅ Offline support (queued reports)

---

## 📋 Recommended (Not Required)

### 1. App Store Screenshots
You'll need:
- **iPhone:** 6.7" (Pro Max), 6.5" (Plus), 5.5"
- **Apple Watch:** Series 7+ (41mm & 45mm)
- **iPad:** 12.9" (if supporting iPad)

### 2. App Preview Videos (Optional but recommended)
- 15-30 seconds showcasing key features
- Watch app in action

### 3. App Description Copy
**Suggest highlighting:**
- Sensory accessibility focus
- AI-powered predictions
- Community-driven data
- Watch app for quick logging
- Privacy-first design

### 4. Keywords
Suggested: accessibility, sensory, autism, ADHD, quiet places, noise levels, neurodiverse, SPD, sensory processing

### 5. Age Rating
**Recommend:** 4+ (no objectionable content)

### 6. Category
**Primary:** Health & Fitness or Navigation
**Secondary:** Lifestyle or Medical

---

## 🐛 Nice to Have (Quality Improvements)

### iOS App
- ⚠️ No onboarding tutorial (first-time users might be confused)
- ⚠️ No in-app help/FAQ
- ⚠️ No feedback/support mechanism
- ✅ Error handling present
- ✅ Offline mode works
- ✅ Loading states

### Watch App
- ✅ Beautiful design
- ✅ Core functionality complete
- ✅ Offline queueing
- ⚠️ No onboarding/first launch tutorial
- ⚠️ Could add complications (show score on watch face)

### Data & Backend
- ⚠️ No backend server (all data is local)
  - Reports aren't shared between users
  - "Sync" button doesn't actually sync to cloud
  - Each user only sees their own reports
- ⚠️ AI predictions require OpenAI API key in app (cost concerns)

### Privacy & Security
- ⚠️ No data encryption at rest
- ⚠️ No backend authentication (just OAuth tokens)
- ⚠️ API keys in client app (can be extracted)

---

## 🚀 Pre-Submission Checklist

### Testing
- [ ] Test on physical iPhone (not just simulator)
- [ ] Test on physical Apple Watch
- [ ] Test all authentication flows (Google, Apple, Anonymous)
- [ ] Test offline mode
- [ ] Test account deletion (once implemented)
- [ ] Test on different iOS versions (iOS 17.0+)
- [ ] Test with VoiceOver (accessibility)
- [ ] Test with different text sizes (Dynamic Type)
- [ ] Check memory usage/leaks with Instruments

### Code
- [ ] Remove debug logs
- [ ] Remove test data
- [ ] Remove unused files
- [ ] Archive builds successfully
- [ ] No compiler warnings (fix or suppress)

### Legal
- [ ] Create Privacy Policy
- [ ] Host privacy policy online
- [ ] (Optional) Terms of Service
- [ ] Implement account deletion
- [ ] Age rating appropriate
- [ ] Export compliance (encryption declaration)

### App Store Connect
- [ ] App Store icon (1024x1024)
- [ ] Screenshots for all device sizes
- [ ] App description written
- [ ] Keywords selected
- [ ] Support URL (can be email: mailto:)
- [ ] Marketing URL (optional)
- [ ] Privacy policy URL ⚠️ REQUIRED
- [ ] Age rating selected
- [ ] Export compliance answered

---

## 💡 Quick Wins to Add Now

### 1. Add Privacy Policy Link to AboutView
```swift
Link("Privacy Policy", destination: URL(string: "YOUR_PRIVACY_URL")!)
Link("Terms of Service", destination: URL(string: "YOUR_TERMS_URL")!)
```

### 2. Add Account Deletion to ProfileView
```swift
Button("Delete Account", role: .destructive) {
    showDeleteAccountConfirmation = true
}
```

### 3. Add Support Email
Add to AboutView:
```swift
Link("Contact Support", destination: URL(string: "mailto:support@hushmap.com")!)
```

---

## 📝 Sample Privacy Policy Outline

```markdown
# HushMap Privacy Policy

## Data We Collect
- Location data (to show nearby places)
- Noise reports you create
- Environmental sound levels (Watch app, via HealthKit)
- Account info (name, email from Google/Apple)

## How We Use Data
- Show you quiet places nearby
- Generate AI predictions about noise levels
- Improve accessibility recommendations
- Sync data between iPhone and Apple Watch

## Third-Party Services
- Google Maps Platform (map display, places search)
- OpenAI (AI predictions)
- Google Sign-In / Apple Sign-In (authentication)

## Data Sharing
- We do NOT sell your data
- We do NOT share personal info with third parties
- Location data stays on your device
- Reports are stored locally (not shared with other users)

## Your Rights
- Delete your account anytime
- Export your data (request via email)
- Opt-out of AI features
- Use app anonymously

## Data Retention
- Account data: Until you delete account
- Reports: Stored locally on your device
- HealthKit data: Never stored, read-only access

## Contact
support@hushmap.com
```

---

## 🎯 Bottom Line

**Can you submit now?** ⚠️ **Almost, but you MUST add:**
1. Privacy Policy URL (host online, add to App Store Connect)
2. Account deletion feature
3. Test on physical devices

**Recommended before submission:**
- Add support email/link
- Add privacy policy link in app
- Clean up any debug code
- Final testing round

**After approval, consider:**
- Backend server for shared reports
- Cloud sync for real
- Watch complications
- In-app help/tutorial

---

**Estimated time to App Store ready:** 4-8 hours
- Privacy policy: 2-3 hours
- Account deletion: 1-2 hours
- Testing & polish: 1-3 hours
