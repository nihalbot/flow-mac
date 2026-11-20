# Flow for Mac ⏱

A native, minimalist Pomodoro & Focus Timer for macOS designed to keep you in a deep flow state, inspired by [flow.app](https://www.flow.app/). Built with **Swift** and **SwiftUI**, packed with all updated free and Pro features.

---

## ✨ Features Breakdown

### 1. 🎛 Menu Bar Integration
* **Glanceable Timer:** Lives right in your macOS menu bar with customizable display formats:
  * **Icon & Time** (e.g. `⚡ 24:59`)
  * **Time Only** (`24:59`)
  * **Icon Only**
* **Instant Controls:** Click the menu bar icon to reveal the HUD Popover, or right-click for quick actions (Start/Pause, Skip, Reset, Preferences, Quit).
* **Dock Independence:** Runs background-first as an accessory app with zero dock clutter (or enable dock icon anytime in Preferences).

### 2. ⚡ Core Pomodoro Engine
* **Interval Management:** Standard 25m Focus / 5m Short Break / 15m Long Break rhythms, fully customizable from 1 to 120 minutes.
* **Round Tracker:** Tracks cycles (e.g. Round 2 of 4) before automatically scheduling longer rejuvenating breaks.
* **Auto-Flow Transitions:** Optional toggles to auto-start breaks after focus or auto-start focus sessions when breaks end.
* **Monotonic Drift-Free Timing:** Uses real-time system clock deltas so your countdown never drifts or freezes when your Mac sleeps or wakes.

### 3. 🏷 Custom Session Titles & Categories (Flow Pro)
* **Live Task Titling:** Label your current focus session on the fly (e.g., *"Refactoring authentication API"*).
* **Tagging & Color Coding:** Organize work into color-coded categories: **Coding**, **Design**, **Writing**, **Study**, **Deep Work**, and **Personal** (add/remove custom categories in Preferences).

### 4. 🔒 Commitment Mode (Flow Pro Strict Focus)
* Locks down active focus blocks to prevent impulsive pauses, tab-switching, or premature quitting.
* Displays a mindful friction confirmation prompt if you attempt to pause during an active commitment block.

### 5. 🌿 Full-Screen Mindfulness Break Overlay (Flow Pro)
* When a break starts, a tranquil full-screen window floats over your workspace to truly pull you away from work.
* **Guided Breathing Circle:** Synchronized 4-4-4-4 box breathing animation (Inhale 4s, Hold 4s, Exhale 4s, Rest 4s) to soothe the nervous system.
* **Ergonomic & Eye-Rest Guidance:** Gentle rotating reminders: 20-20-20 rule eye rest, hydration prompts, and shoulder/wrist stretches.
* Press `Esc` or click "Skip Break" anytime to return to work.

### 6. 🛡 Distraction Blocker (App & Website Shield)
* **Application Blocker:** Automatically minimizes or hides distracting Mac applications (Slack, Discord, Messages, Steam, Twitter, Spotify, Telegram) the moment you enter focus mode.
* **Website Blocker:** Integrates with major browsers (**Safari**, **Google Chrome**, **Brave**, **Arc**, **Edge**) to detect distracting domains (`reddit.com`, `twitter.com`, `youtube.com`, `instagram.com`, etc.) and gently redirects them to preserve focus.
* Fully customizable blacklist with quick Add / Remove controls in Preferences.

### 7. 🎧 Audio Engine & Ambient Focus Soundscapes
* **Procedural Chimes (Zero external audio files required!):**
  * **Zen Bell** (pure crystalline resonance)
  * **Tibetan Singing Bowl** (rich harmonic drone)
  * **Digital Chime** (modern 3-tone notification)
  * **Marimba Sparkle** (warm wooden chime)
  * **Tibetan Gong** (deep reverberation)
* **Ambient Sound Generator:**
  * **Clock Ticking / Metronome** (steady rhythm for coding/math)
  * **Gentle Rain** (procedural pink noise)
  * **Ocean Waves** (deep soothing brown noise)
  * **Focus Mask** (neutral white noise)
  * Real-time volume controls directly accessible in the HUD and Settings.

### 8. 📊 Focus Analytics, Daily Streaks & Milestones
* **Streak Tracking:**
  * **Current Streak:** Tracks consecutive active days of completed focus sessions (e.g. `🔥 5d`). If you haven't completed a session yet today, your streak from yesterday stays active until midnight.
  * **Best Ever Streak:** Automatically records and celebrates your all-time longest streak (e.g., `Best: 14 Days`).
  * **Streak Milestones:** Progression titles (**Spark Ignited 🌱**, **In the Flow ⚡️**, **On Fire 🔥**, **Unstoppable Week 🚀**, **Focus Champion 👑**, **Flow Legend 💎**).
  * **Visual 7-Day Habit Tracker:** Interactive day-by-day circle row showing your activity over the last 7 days with glowing flame indicators.
* **Metric Cards:** Today's focus hours, weekly hours, all-time focus minutes, and daily goal progress (e.g. `4 / 8`).
* **24-Hour Activity Chart:** Visualizes when during the day you are most productive.
* **Category Distribution:** Percentage breakdown of time spent per project or topic.
* **History Log & CSV Export:** Searchable list of past sessions with one-click export to CSV.

### 9. ☁️ 100% Free Cloud Synchronization
* **Apple iCloud Drive (Free & Native):** Automatically syncs and backs up your session history, streaks, and categories to your free Apple iCloud Drive (`~/Library/Mobile Documents/com~apple~CloudDocs/FlowApp/sessions_history.json`). Syncs seamlessly across your Macs with zero subscription or setup required.
* **Custom Free Cloud API / Webhook (Optional):** Supports connecting to free cloud database endpoints (such as JSONBin.io free tier, Supabase, Firebase, or a Cloudflare Worker webhook) with secret key support.
* **Manual & Auto-Sync:** Automatically uploads on each completed session, with an instant "Sync to Cloud" button in the Analytics dashboard.

### 9. 📅 Apple Calendar Synchronization (Flow Pro)
* Automatically logs every completed focus session directly into your **Apple Calendar** (`Calendar.app`).
* Creates color-coded event blocks tagged with your session title, category, and exact timestamp.

### 10. ⌨️ Global Keyboard Shortcuts
* **Start / Pause:** `⌘ + ⌥ + Space` or `⌘ + ⌥ + P`
* **Skip Session:** `⌘ + ⌥ + S`
* **Reset Session:** `⌘ + ⌥ + R`

---

## 🚀 Quick Start & Building

The app bundle is pre-built and ready to launch immediately:

### To launch Flow right now:
```bash
cd /Users/nihal/.gemini/antigravity/scratch/FlowApp
./run.sh
```
*(Or simply open `build/Flow.app` in Finder)*

### To rebuild release bundle:
```bash
cd /Users/nihal/.gemini/antigravity/scratch/FlowApp
./build_app.sh
```

### To install to your Applications folder:
```bash
cp -R /Users/nihal/.gemini/antigravity/scratch/FlowApp/build/Flow.app /Applications/
```

---

## 📁 Project Architecture

```
FlowApp/
├── Package.swift                    # Swift Package Manager manifest (macOS 13+)
├── build_app.sh                     # Automated Release packaging & code-signing script
├── run.sh                           # One-click launch script
├── build/
│   └── Flow.app                     # Ready-to-run macOS Application Bundle
├── Resources/
│   ├── Info.plist                   # App bundle configuration & permission strings
│   ├── AppIcon.icns                 # High-resolution multi-scale app icon
│   ├── generate_icon.swift          # Programmatic CoreGraphics icon generator
│   └── make_icns.py                 # Multi-resolution ICNS packager
└── Sources/
    └── FlowApp/
        ├── FlowApp.swift            # NSApplication entry point, Status Item & Window Controllers
        ├── Models/
        │   ├── SessionState.swift   # Focus, Short Break, Long Break, Paused states
        │   ├── SessionCategory.swift# Color-coded tags (Coding, Design, Writing, etc.)
        │   ├── FlowSession.swift    # Persistent session records
        │   ├── SoundEffect.swift    # Alert sounds & Ambient soundscape types
        │   └── AppSettings.swift    # User preferences & UserDefaults storage
        ├── Managers/
        │   ├── TimerManager.swift   # Monotonic clock state machine & commitment mode
        │   ├── DistractionBlocker.swift # App & browser website shield
        │   ├── SoundEngine.swift    # Procedural audio synthesis (AVAudioEngine)
        │   ├── HistoryManager.swift # Analytics, daily streaks & CSV export
        │   ├── CalendarManager.swift# Apple Calendar (Calendar.app) sync
        │   ├── HotkeyManager.swift  # Global keyboard shortcuts
        │   └── NotificationManager.swift # macOS User Notifications
        └── Views/
            ├── MenuBarHUDView.swift # The signature circular timer Popover UI
            ├── FullScreenBreakView.swift # Distraction-free full-screen break overlay
            ├── StatsDashboardView.swift # Analytics charts, streaks & history
            ├── PreferencesView.swift# Multi-tab settings panel
            └── Components/
                ├── CircularTimerProgress.swift # Animated circular gradient timer ring
                ├── BreathingCircleView.swift   # Box-breathing animation guide
                └── StatBarChart.swift          # 24-hour activity distribution chart
```
