# project_assignment_tracker

## Assignment Tracker

A Flutter offline assignment and payment tracker. It stores assignments, due dates, and payment status locally with SQLite (`sqflite`).

- Original location: `D:\projects\Assignment_Tracker_Flutter_Starter`
- Working copy: `D:\PROJECTS_READY\project_assignment_tracker`
- Stack: Flutter, Dart, sqflite, intl

## Folder layout

```text
project_assignment_tracker/
  app/        Flutter application
  database/   Database notes and schema reference
  docs/       Project documentation
```

## Setup and run

```powershell
cd app
flutter pub get
flutter analyze
flutter test
flutter run
```

## Verified status (2026-11-09)

- [x] Dependencies resolved with `flutter pub get`
- [x] `flutter analyze` completed with no issues
- [x] `flutter test` passed 1/1 test
- [ ] Release APK not built during this verification pass

## Notes and limitations

- The app is offline and stores data locally with SQLite.
- No backend or environment variables are required.
- Generated build output and local databases are ignored by Git.

## Troubleshooting

- **No devices found**: start an emulator or connect a device, then run `flutter devices`.
- **Database errors on desktop**: the project uses `sqflite_common_ffi` in tests; mobile/desktop runtime setup may differ.
- **Build cache issues**: `flutter clean` and retry.
