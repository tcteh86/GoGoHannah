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
- Practice screen (vocab generation + answer check, English-first bilingual reveal cards)
- Quiz tab (recommended-word quiz, bilingual ON by default with toggle)
- Past Results (summary + recent)
- Navigation flow: Practice → Quiz → Results

## Backend dependency
The app calls the FastAPI backend in `backend/` for exercise generation and
progress storage.

## Deploy (Firebase Hosting)
From `frontend/`:
1) Build the web app:
   - `flutter build web --dart-define API_BASE_URL=https://YOUR-RENDER-URL`
2) Set your Firebase project:
   - Update `.firebaserc` with your project ID.
3) Deploy:
   - `firebase deploy --only hosting`

## Deploy (Render Static Site)
If you build on Render, Flutter can be cached between builds. Use a guarded
clone to avoid `destination path ... already exists` errors.

Example build command:
- `bash -lc "if [ ! -d /opt/render/flutter ]; then git clone https://github.com/flutter/flutter.git -b stable --depth 1 /opt/render/flutter; fi && export PATH=\"/opt/render/flutter/bin:$PATH\" && flutter pub get && flutter build web --dart-define API_BASE_URL=$API_BASE_URL"`

Publish directory:
- `build/web`
