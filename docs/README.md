# Assignment Tracker (Flutter / Android)

A personal, offline assignment and payment tracker. Data is saved locally in SQLite on the Android device.

## Features in this starter version
- Dashboard: total expected fees, amount received, and outstanding balance
- Add, edit, and delete assignments
- Assignment name, semester/client, date added, due date, total fee, amount paid, work status, and notes
- Automatic payment status: Paid, Partially paid, Pending, or Fee not set
- Filter assignments by payment and work status
- NPR currency formatting
- Local SQLite database; no account or internet connection required

## Requirements
- Flutter SDK installed
- Android Studio (Android SDK and emulator) or an Android phone with USB debugging enabled
- Android device/emulator

## Run the app
1. Unzip the project.
2. Open a terminal in the `assignment_tracker` folder.
3. Run:
   ```bash
   flutter doctor
   flutter pub get
   flutter run
   ```
4. Choose your Android emulator or connected phone when Flutter asks.

## Build an APK
Run:
```bash
flutter build apk --release
```
The APK is usually created at:
`build/app/outputs/flutter-apk/app-release.apk`

Copy that APK to your Android phone and install it. Android may ask you to allow installation from that source.

## Important notes
- This first version stores data only on this device. Uninstalling the app or clearing its data may delete the database. Export/backup is not implemented yet.
- No cloud sync, login, or multi-user support is included.
- Amount Paid means the total received to date, not the latest instalment.
- The starter project intentionally does not preload uncertain screenshot entries. Add or edit them after checking the correct names and amounts.
