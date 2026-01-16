# GoGoHannah Frontend (Flutter Web)

This directory is reserved for the Flutter app. The milestone target is Flutter
web first, then Android after the web demo is stable.

## Local setup (developer machine with Flutter)
1) Install Flutter SDK.
2) Fetch dependencies:
   - `flutter pub get`
3) Run the web app:
   - `flutter run -d chrome --dart-define API_BASE_URL=http://localhost:8000`

## Milestone scope
- Practice screen (vocab generation + answer check)
- Past Results (summary + recent)
- Test & Check (quick quiz)

## Backend dependency
The app calls the FastAPI backend in `backend/` for exercise generation and
progress storage.
