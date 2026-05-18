# Release Guide — KopiyanteaPOS

End-to-end release procedure: build, sign, certificate rotation, store submission.

## 1. Version bump

```yaml
# pubspec.yaml
version: 0.2.0+5   # <name>+<buildNumber>
```

- `name` follows SemVer (major.minor.patch) — visible to users
- `buildNumber` is a monotonic integer — required by Play Store and App Store

Bump in a dedicated commit so the version change is easy to revert if the build fails.

## 2. Pre-flight checklist

- [ ] All Phase X — DONE QA in `PROJECT_STATUS.md`
- [ ] `flutter analyze` — zero warnings (`infos` from TODOs are OK)
- [ ] `flutter test` — all green
- [ ] `dart run build_runner build --delete-conflicting-outputs` — runs clean
- [ ] `.env` matches the target environment (staging vs production)
- [ ] `SUPABASE_CERT_FINGERPRINTS` populated in production builds (validated by `Env.validate()`)
- [ ] All pending Supabase migrations applied to the target project
- [ ] Tested on a real device (not just emulator) — Bluetooth printer, scanner, sign-in

## 3. Android — release build

### One-time keystore setup

```bash
keytool -genkey -v -keystore ~/kopiyantea-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias kopiyantea
```

Store the keystore + password in a password manager. **Never commit it.**

Create `android/key.properties` (gitignored):

```properties
storePassword=...
keyPassword=...
keyAlias=kopiyantea
storeFile=/absolute/path/to/kopiyantea-release.jks
```

Wire into `android/app/build.gradle` (one-time edit):

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'),
                          'proguard-rules.pro'
        }
    }
}
```

### Build commands

```bash
# Split-per-ABI APKs (smaller downloads, fewer Play Store reviews)
flutter build apk --split-per-abi --release

# Or App Bundle (preferred for Play Store)
flutter build appbundle --release
```

Outputs:
- APKs: `build/app/outputs/flutter-apk/app-*-release.apk`
- AAB:  `build/app/outputs/bundle/release/app-release.aab`

### Smoke-test the release APK

Install the release APK on a real device and walk through:
1. Sign in (Supabase auth — production credentials)
2. Sync — pull master data
3. POS flow — create transaction
4. Print receipt — verify the formatter renders correctly
5. Sign out

## 4. iOS — TestFlight (when in scope)

```bash
flutter build ipa --release
open build/ios/archive/Runner.xcarchive
# In Xcode: Distribute App → App Store Connect → Upload
```

Requires:
- Apple Developer account
- App Store Connect app record
- iOS distribution certificate + provisioning profile

## 5. Certificate-pinning rotation (ADR-0010)

Certificates expire. The Supabase TLS leaf changes when the project rotates its cert (Letsencrypt auto-renew, ~60-day cycle). Pinning will reject the new cert until the app ships with its fingerprint.

### Rotation procedure

1. **Get the new fingerprint** ahead of expiry:
   ```bash
   echo | openssl s_client -servername PROJECT.supabase.co \
                           -connect PROJECT.supabase.co:443 2>/dev/null \
     | openssl x509 -fingerprint -sha256 -noout \
     | sed 's/SHA256 Fingerprint=//'
   ```
2. **Ship an overlap build** with both old and new fingerprints in `SUPABASE_CERT_FINGERPRINTS` (comma-separated). Get this build to ≥ 95% of installs.
3. **After the soak window** (Section 14 risk #9 of MASTER_PROMPT_v5.md — 30 days minimum), ship a build with only the new fingerprint.

Failing to overlap means clients still on the old build will be cut off the moment the cert rotates.

## 6. Play Store submission

- **Internal testing track** first — invite the development team
- **Closed testing** — invite store managers / cashiers for real-device testing
- **Open testing / Production** — only after closed testing passes

Required listing assets:
- App name + short description (Indonesian + English)
- Feature graphic (1024×500)
- Screenshots: phone + 7-inch tablet + 10-inch tablet
- Privacy policy URL
- Content rating questionnaire

## 7. Post-release

- Tag the commit: `git tag v0.2.0 && git push origin v0.2.0`
- Update `PROJECT_STATUS.md` — note the released version
- Monitor Supabase logs for auth / sync errors in the first 24 hours
- If a critical bug surfaces: file under `## Bug Log` in `PROJECT_STATUS.md`, follow non-destructive migration policy (ADR-0008) for any schema fixes
