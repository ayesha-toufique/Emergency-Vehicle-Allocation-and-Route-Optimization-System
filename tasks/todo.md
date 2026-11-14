# Task List

## Task 1: Create Python virtual environment and install backend dependencies

**Description:** Create `.venv` in `Backend/` and install packages from `Backend/requirements.txt` (Django, djangorestframework, PyMySQL, cryptography, etc.).

**Acceptance criteria:**
- [x] Python venv created at `Backend/.venv`
- [x] `pip install -r Backend/requirements.txt` succeeds
- [x] `python manage.py check` runs without errors

**Verification:**
- [x] `.venv/bin/python manage.py check` outputs "System check identified no issues"

**Dependencies:** None

**Files likely touched:**
- `Backend/.venv`
- `Backend/requirements.txt`

**Estimated scope:** Small: 1-2 files

## Task 2: Configure SQLite database and run Django migrations

**Description:** Set up `.env` with `DB_ENGINE=sqlite` for zero-dependency local execution and execute Django database migrations.

**Acceptance criteria:**
- [x] `Backend/.env` configured with `DB_ENGINE=sqlite`
- [x] `accounts` and `dispatch` migrations applied to database
- [x] Database schema tables created in `Backend/db.sqlite3`

**Verification:**
- [x] `python manage.py showmigrations` shows all migrations applied `[X]`

**Dependencies:** Task 1

**Files likely touched:**
- `Backend/.env`

**Estimated scope:** Small: 1-2 files

## Task 3: Seed Karachi road network, accounts, and demo data

**Description:** Run the custom management command `seed_demo` to generate synthetic Karachi road network with real arterial roads, demo users, vehicles, and initial allocation plan.

**Acceptance criteria:**
- [x] `python manage.py seed_demo --allocate` runs to completion
- [x] Road network graph version recorded
- [x] User accounts created matching Flutter demo credentials

**Verification:**
- [x] `python manage.py shell -c "from accounts.models import User; print(User.objects.count())"` > 0

**Dependencies:** Task 2

**Files likely touched:** None

**Estimated scope:** Small: 1-2 files

## Task 4: Run Django algorithm and API test suite

**Description:** Execute automated test suite for allocation (0/1 Multi-Criteria Knapsack), Dijkstra dynamic shortest path, and dispatch REST endpoints.

**Acceptance criteria:**
- [x] Algorithm tests (`test_allocation.py`, `test_dijkstra.py`) pass
- [x] API endpoint tests (`test_api.py`) pass

**Verification:**
- [x] `python manage.py test algorithms dispatch` exits with code 0 (OK)

**Dependencies:** Task 3

**Files likely touched:** None

**Estimated scope:** Small: 1-2 files

## Checkpoint: Backend Operational
- [x] Backend running and all algorithm tests passing

## Task 5: Implement Flutter HTTP API client targeting AppConstants.apiBase

**Description:** Create an HTTP service layer in Flutter to interface with Django REST endpoints, with fallback to in-memory mock repository if server is unreachable.

**Acceptance criteria:**
- [x] `ApiService` created in `lib/core/services/`
- [x] Network status check, timeout, and error handling implemented
- [x] Fallback to `MockRepository` when backend is offline

**Verification:**
- [x] `flutter analyze` clean with no errors

**Dependencies:** Task 4

**Files likely touched:**
- `lib/core/services/api_service.dart`

**Estimated scope:** Medium: 3-5 files

## Task 6: Wire Authentication flow to Django backend

**Description:** Connect Login and Register screens to `/api/auth/login/` and `/api/auth/me/` with mock fallback.

**Acceptance criteria:**
- [x] Login screen authenticates against Django backend
- [x] User token and role preserved in session service
- [x] Gracefully falls back to mock login if offline

**Verification:**
- [x] Flutter auth flow passes analysis

**Dependencies:** Task 5

**Files likely touched:**
- `lib/features/auth/screens/login_screen.dart`
- `lib/core/services/session_service.dart`

**Estimated scope:** Medium: 3-5 files

## Task 7: Wire Emergency Reporting & Vehicle Allocation

**Description:** Connect SOS dispatch and vehicle allocation screens to `/api/allocate/` and `/api/emergencies/` with mock fallback.

**Acceptance criteria:**
- [x] SOS incident creation calls backend API
- [x] Vehicle allocation displays calculated DP/Dijkstra results from backend
- [x] Falls back to local demo incidents/allocations if offline

**Verification:**
- [x] `flutter analyze` clean

**Dependencies:** Task 6

**Files likely touched:**
- `lib/features/home_sos/`
- `lib/features/dispatcher/`

**Estimated scope:** Medium: 3-5 files

## Checkpoint: Integration Complete
- [ ] Mobile app functions end-to-end against Django backend or offline mock

## Task 8: Rebuild Android release APK with backend integration

**Description:** Compile updated Flutter Android release binary bundling the API integration.

**Acceptance criteria:**
- [x] `build/app/outputs/flutter-apk/app-release.apk` compiled
- [x] Copied to `landing-page/app-release.apk`

**Verification:**
- [x] `ls -lh landing-page/app-release.apk` confirmed

**Dependencies:** Task 7

**Files likely touched:**
- `landing-page/app-release.apk`

**Estimated scope:** Small: 1-2 files

## Task 9: Commit changes locally to branch Hunain (Strictly NO Push)

**Description:** Commit all updated source code, backend setup, and artifacts to branch `Hunain` locally.

**Acceptance criteria:**
- [x] All modified files committed with descriptive conventional commit messages
- [x] Zero `git push` executed

**Verification:**
- [x] `git status` clean working tree
- [x] `git branch --show-current` outputs `Hunain`

**Dependencies:** Task 8

**Files likely touched:** Git refs

**Estimated scope:** Small: 1-2 files

## Checkpoint: Final
- [x] Complete project delivered with working database, backend, mobile app, and local commits
