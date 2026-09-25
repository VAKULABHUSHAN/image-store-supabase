# PersonaLens Mobile — Flutter Voice & Vision Application

**PersonaLens Mobile** is a cross-platform Flutter application (Android, iOS, Windows, macOS, Web) designed for hands-free voice interaction, live captions, speaker separation, voice enrollment, and real-time face recognition. It connects seamlessly to a local **FastAPI Backend Server** and **Supabase Authentication Gateway**.

---

## 🌟 Key Features

- **🎙️ Real-Time Voice Streaming & Live Captions**
  - Continuous 16kHz PCM 16-bit mono audio streaming via WebSocket (`/ws/live`) directly to backend host running **Whisper**.
  - Displays live captions with real-time speaker attribution (**Host**, **Other**, or **Named Person**).
  - 15-second automatic silence detector to finalize and log conversations automatically.

- **📻 Hands-Free Landscape Standby Mode**
  - Dedicated landscape UI designed for ambient room listening.
  - Interactive radial waveform visualization that reacts dynamically to ambient volume/RMS levels.
  - Automatically triggers session recording upon detecting speech.

- **📸 Vision & Face Recognition (Section 11 Spec)**
  - Select photos from Gallery or capture with Camera.
  - Direct upload to `POST /recognize?wait=true` on the FastAPI server with bounding box overlay calculations.
  - **Matched Faces**: Highlighted with solid teal boxes and confidence percentages (e.g., `Olive (99%)`).
  - **Unmatched Faces**: Highlighted with amber boxes. Tapping an unmatched box opens the **Save Unknown Person** modal (`POST /person`).

- **🗣️ Host Voice Enrollment**
  - First-run host voice print recording (`≥ 5s` audio sample) uploaded to `POST /voice/enroll` so the backend can distinguish the host's voice from others.

- **👥 People & Session History**
  - Browse recognized individuals (`GET /people`) with first-met and most-recent interaction summaries.
  - Review 50 latest sessions (`GET /sessions`) with host vs. other speech share visual bars and full transcript breakdowns.
  - Name unassigned speakers post-session.

- **⚙️ Dynamic Server Host Configuration**
  - In-app **Server Settings** dialog to update the backend IP address (`serverHost`) dynamically over LAN/Hotspot connections with live health check testing (`GET /health`).

- **🎨 Themes & Auth**
  - Dynamic Dark and Light mode theme switching.
  - Username + Password authentication powered by Supabase.

---

## 🏗️ Architecture Overview

All AI recognition models run on the **backend host server**, keeping the mobile app lightweight:

```
┌────────────────────────────────┐         WebSocket (/ws/live) PCM Stream       ┌───────────────────────────────┐
│                                │ ────────────────────────────────────────────► │  FastAPI Backend (:8120)      │
│  PersonaLens Mobile            │ ◄──────────────────────────────────────────── │  - Whisper STT (English)      │
│  (Flutter Client App)          │         Live Captions & Speaker Labels        │  - pyannote Speaker Separation│
│                                │                                               │  - Face Embeddings Vision     │
│                                │ ─────── POST /recognize?wait=true ──────────► │  - Cloud LLM Summaries        │
└───────────────┬────────────────┘                                               └───────────────┬───────────────┘
                │                                                                                │
                │                        Supabase REST Auth & API                                │
                └────────────────────────────────────────────────────────────────────────────────┘
                                            (Docker Gateway :8000)
```

---

## 🛠️ Prerequisites & Setup

### 1. Requirements
- **Flutter SDK**: `^3.10.4` or higher
- **Dart SDK**: `^3.10.4`
- **Backend Host**: FastAPI server (`:8120`) & Supabase Docker (`:8000`) running on the local network (LAN / Mobile Hotspot).

### 2. Permissions Configured
- **Android** (`android/app/src/main/AndroidManifest.xml`):
  - `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS`, `INTERNET`, `CAMERA`, `usesCleartextTraffic="true"`.
- **iOS** (`ios/Runner/Info.plist`):
  - `NSMicrophoneUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`.

---

## 🚀 Getting Started

### 1. Install Dependencies
Run the following command in the project root:

```bash
flutter pub get
```

### 2. Verify Backend Connectivity
Replace `<host-ip>` with your backend machine's LAN IP address (e.g. `192.168.137.43`):

```powershell
# Windows PowerShell
Test-NetConnection <host-ip> -Port 8000
Test-NetConnection <host-ip> -Port 8120
curl.exe http://<host-ip>:8120/health          # -> {"status":200}
curl.exe http://<host-ip>:8000/auth/v1/health  # -> JSON response
```

### 3. Run the App
Launch on your connected physical mobile device or emulator:

```bash
flutter run -d <device_id>
```

---

## 📱 Navigation & Workflows

1. **Auth / Login**: Enter your Username & Password. Sign-up maps usernames to synthetic email formats (`username@persona-lens.local`).
2. **Server Settings**: Tap the server settings icon to configure host IP (`e.g., 192.168.137.43`) and test backend reachability.
3. **Standby Mode**: Tap **Standby** in the bottom navigation. Rotate to landscape mode to view the audio visualizer, ambient silence counter, and live Whisper caption stream.
4. **Vision (Gallery)**: Tap **Gallery** to select or snap a photo. Detect faces, view overlay bounding boxes, and enroll new people directly.
5. **People & History**: Access from the Profile screen to view past interaction summaries and manage person profiles.

---

## 📂 Codebase Structure

```
lib/
├── Auth/                      # Authentication (Login & Signup UI)
│   ├── login.dart
│   └── signup.dart
├── api_service.dart           # FastAPI REST client (Health, Voice, Recognize, Sessions, People)
├── live_caption_service.dart  # WebSocket streaming client for live Whisper captions
├── main.dart                  # Application entry point & global config
├── main_navigation_shell.dart # 4-Tab Bottom Navigation bar & orientation controller
├── standby_screen.dart        # Landscape Standby UI & real-time PCM microphone streaming
├── imageget.dart              # Vision & Face recognition screen with bounding box overlay
├── session_result_sheet.dart  # Post-session summary, transcript & speech-share bottom sheet
├── name_prompt_dialog.dart    # Post-session speaker naming modal
├── voice_enrollment_screen.dart # Host voice profile enrollment screen
├── server_settings_dialog.dart # In-app host IP address configuration dialog
├── profile_page.dart          # User profile settings & theme toggles
├── people_and_history_page.dart # Known people & past session logs view
└── wav_encoder.dart           # PCM 16-bit mono to WAV encoder helper
```

---

## 📜 License & Acknowledgments

Built for the **PersonaLens** voice & vision project. Powered by Flutter, FastAPI, Whisper, pyannote, and Supabase.
