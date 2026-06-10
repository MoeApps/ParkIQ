# ParkIQ — Session Handoff Log

> **Purpose:** Running log of what was done each session, what worked, what failed, and what remains. New agents: read **`PROJECT_KNOWLEDGE.md`** first, then check the latest entry below.

---

## How to use this file

After each working session, **add a new dated section at the top** (below this header) with:

- What was attempted
- What worked ✅
- What did not work ❌
- What's left to do 📋
- Commands run / branches / blockers

---

## Session: 2026-06-10 — ESP entry workflow rewrite

**Agent / context:** User requested major hardware workflow changes in `ESP.txt`.

### What we did

- Rewrote **`ESP.txt`** entry flow, pending-car queue, reservation-by-slot API, and full-parking logic.

### What changed in ESP firmware ✅

1. **Entry gate menu** — Default idle screen: `WELCOME TO` / `PARKIQ`. When entry IR triggers, LCD shows `1=GET PIN` / `2=RESERV PIN`.
2. **Press 1** — If a free slot exists, generates unique 2-digit PIN, opens entry gate, queues car as walk-in. If full → `PARKING FULL`.
3. **Press 2** — User enters reservation PIN on keypad. Valid → gate opens for booked slot. Invalid → `NO RESERVATION`, back to menu.
4. **Leave gate** — When entry IR clears, returns to ParkIQ welcome screen.
5. **FIFO slot assignment** — Cars that entered after gate opens are queued; each newly occupied slot sensor gets the **oldest waiting car's PIN** (handles out-of-order parking, e.g. cars 1–4 → slots 2,4,3,1).
6. **Full parking** — `freeSlots` = slots that are neither occupied nor reserved. When 0, walk-in entry (press 1) blocked; reserved users can still enter with press 2.
7. **App reservations** — `POST /reserve` now accepts JSON `{ "slot": 1..4, "pin": optional, "user": "mobile" }`, marks that slot `reserved`, returns `{ slot, pin }`. `POST /cancel` accepts `{ "slot" }` or `{ "user" }`.

### What did not work ❌ / not done yet

- **Not flashed/tested on hardware** — logic is code-only this session.
- **Flutter app not updated** — `parking_service.dart` still mock; must send `{ slot, pin }` on reserve.
- **App still does not compile** — `reservation.dart` corruption unchanged.

### API change for app integration 📋

```json
POST /reserve
{ "slot": 2, "pin": 45, "user": "mobile" }

Response 200:
{ "message": "Reservation Added", "slot": 2, "pin": 45 }
```

User enters that PIN at entry keypad (press 2) to open gate and park in slot 2.

### Files modified

- `ESP.txt` — full workflow rewrite

---

## Session: 2026-06-10 — Initial exploration & documentation

**Agent / context:** First documentation session. User requested full project exploration (ESP firmware + Flutter app) and creation of onboarding docs for future agents.

### What we did

- Read and analyzed **`ESP.txt`** (full ESP32 firmware: sensors, servos, LCD, keypad, WiFi AP, REST API).
- Explored entire Flutter app under **`lib/`** (4 screens, 2 services, models, theme, widgets).
- Read **`README.md`** and **`pubspec.yaml`**.
- Ran **`flutter pub get`** and **`flutter analyze`** — confirmed compile state.
- Created **`PROJECT_KNOWLEDGE.md`** (comprehensive system reference).
- Created **`SESSION_HANDOFF.md`** (this file).

### What worked ✅

- **ESP firmware design is complete and understandable** — clear pin map, entry/exit flow, 4 slot IR detection, HTTP server on port 80, WiFi AP `ParkingSystem` / `12345678`.
- **Flutter UI structure is well-organized** — clean separation: screens → `ParkingService` → (future) ESP. Good comments for beginners.
- **Mock mode lets you reason about UX** without hardware — login, 3-step reserve, PIN/QR screen all implemented at UI level.
- **`PricingService`** is fully implemented (peak/weekend/VAT) and ready to plug into an exit/billing screen.
- **Documentation** — `PROJECT_KNOWLEDGE.md` now captures API mismatch, pin map, and integration steps.

### What did not work ❌ / blockers

- **App does not compile** — `lib/models/reservation.dart` has corrupted duplicate definitions (likely bad merge). `flutter analyze` reports 50+ errors; `Reservation` type is broken across the app.
- **`AppColors.blue` undefined** — `reserve_screen.dart` line ~471 references missing color constant.
- **App ↔ ESP API mismatch** — README documents `/login`, `/lots`, `/gate`; ESP only has `/status`, `/spots`, `/revenue`, `/reserve`, `/cancel`, `/openEntry`, `/openExit`.
- **Architecture mismatch** — App: 4 lots × 24 spots, 4-digit PIN, QR codes. ESP: 1 lot × 4 slots, 2-digit PIN, physical keypad, no QR.
- **WiFi model mismatch** — App docs say "same WiFi network" with LAN IP; ESP runs as **Access Point** (`192.168.4.1`), phone must join `ParkingSystem` SSID.
- **No `.gitignore`** — repo has many untracked `.dart_tool/` and `build/` artifacts.
- **No git history explored** — `git log` was skipped; commit timeline unknown.
- **Hardware not tested this session** — no live ESP or phone-on-AP testing performed.

### Commands run

```bash
flutter pub get    # succeeded — dependencies resolved
flutter analyze    # failed — 104 issues (mostly reservation.dart)
```

### Key findings for next session

| Priority | Task | File(s) |
|----------|------|---------|
| P0 | Fix corrupted `Reservation` / `ParkingSpot` models | `lib/models/reservation.dart` |
| P0 | Add `AppColors.blue` or replace with existing color | `lib/theme/app_theme.dart`, `reserve_screen.dart` |
| P1 | Set `ESP_BASE_URL` to `http://192.168.4.1` | `parking_service.dart` |
| P1 | Wire `getSpots()` + `getLots()` to ESP `/spots` + `/status` | `parking_service.dart` |
| P1 | Wire `triggerGate()` → `/openEntry` | `parking_service.dart`, `entry_pin_screen.dart` |
| P2 | Simplify reserve UI to 4 slots (match hardware) | `reserve_screen.dart`, `parking_service.dart` |
| P2 | Align PIN format (2-digit ESP vs 4-digit app) | design decision needed |
| P2 | Integrate `PricingService` into exit/billing UI | new screen or extend entry screen |
| P3 | Add `.gitignore` for Flutter (`build/`, `.dart_tool/`) | repo root |
| P3 | Update `README.md` to match real ESP API | `README.md` |
| P3 | Android cleartext HTTP permission if testing on device | `android/app/src/main/AndroidManifest.xml` |

### Integration approach recommended

**Minimal demo path:** Fix compile errors → connect phone to ESP AP → show real 4-spot occupancy on dashboard → POST `/reserve` on confirm → "Request Gate Open" calls `/openEntry` → user exits via **physical keypad** at gate (ESP-native flow).

**Do not assume** app PIN matches ESP entry PIN unless firmware is extended to accept/return app-generated PINs via API.

### Open questions (need user input)

1. Should the app be simplified to **one lot / 4 spots** to match hardware, or will more slots be added later?
2. Is **QR code** required for demo, or is physical keypad exit enough?
3. Should billing follow **ESP flat 20/hr** or **PricingService** (peak/weekend/VAT)?
4. Will ESP stay in **AP mode** or switch to **STA mode** (join home WiFi)? This changes `ESP_BASE_URL` strategy.
5. Is **login** purely cosmetic, or should ESP store users?

### Files created this session

- `PROJECT_KNOWLEDGE.md` — full system reference for agents
- `SESSION_HANDOFF.md` — this handoff log

### Files not modified

- No source code changes this session (exploration + docs only).
- No git commits (user did not request).

---

<!-- Copy the template below for the next session -->

<!--
## Session: YYYY-MM-DD — [short title]

**Agent / context:** [who/what prompted the work]

### What we did
- 

### What worked ✅
- 

### What did not work ❌ / blockers
- 

### Commands run
```bash

```

### What's left 📋
- [ ] 

### Notes for next agent
- 

-->
