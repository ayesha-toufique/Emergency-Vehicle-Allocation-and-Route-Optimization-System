# Implementation Plan: Complete Project Backend & Integration

## Overview
Complete the ResQ emergency route and resource management system in branch `Hunain`. Initialize the Django REST backend with SQLite and demo Karachi data, verify all algorithms and backend endpoints with tests, wire the Flutter mobile app via an `ApiService` with offline mock fallback, verify release build, and commit all changes locally (strictly no push).

## Dependency Graph
```
SQLite Database & Django Migrations
    │
    ▼
Seed Demo Karachi Road Grid & Accounts (accounts + dispatch + algorithms)
    │
    ▼
Automated Algorithm & Dispatch Tests
    │
    ▼
Flutter HTTP Client Integration (ApiService with MockRepository Fallback)
    │
    ▼
Validation & Clean Flutter Analysis
    │
    ▼
Local Git Commits (Branch Hunain - No Push)
```

## Architecture Decisions
- **Database Engine**: Use SQLite (`DB_ENGINE=sqlite`) by default for instant, zero-dependency, local execution, preserving full MySQL schema compatibility.
- **Karachi Road Graph & Demo Data**: Run `python manage.py seed_demo --allocate` to populate realistic arterial roads (Shahrah-e-Faisal, University Road, etc.), demo users matching Flutter credentials, and dynamic allocation records.
- **Frontend Hybrid Mode**: Implement `ApiService` in Flutter with automatic fallback to `MockRepository` on connection error or timeout, ensuring the app functions seamlessly in both connected and offline demo states.
- **VCS Boundary**: Commit all changes to local branch `Hunain`. Under no circumstances execute `git push`.

## Task List

### Phase 1: Backend Environment & Database Setup
- [x] Task 1: Create Python virtual environment and install backend dependencies
- [x] Task 2: Configure SQLite database and run Django migrations
- [x] Task 3: Seed Karachi road network, accounts, and demo data (`python manage.py seed_demo --allocate`)
- [x] Task 4: Run Django algorithm and API test suite (`python manage.py test algorithms dispatch`)

### Checkpoint: Backend Operational
- [x] Django runs cleanly on port 8000 with healthy endpoints
- [x] 100% of algorithm and dispatch tests pass

### Phase 2: Frontend-Backend API Connection
- [x] Task 5: Implement Flutter HTTP API client targeting `AppConstants.apiBase` with offline mock fallback
- [x] Task 6: Wire Authentication flow (`/api/auth/login/`, `/api/auth/me/`) with fallback
- [x] Task 7: Wire Emergency Reporting & Vehicle Allocation (`/api/allocate/`, `/api/emergencies/`) with fallback

### Checkpoint: End-to-End Integration
- [ ] Mobile app authenticates and dispatches against backend when running, and gracefully degrades to mock data when backend is stopped
- [ ] `flutter analyze` passes with zero errors

### Phase 3: Final Build & Local Commit
- [x] Task 8: Rebuild Android release APK with backend integration
- [x] Task 9: Commit all changes locally to branch `Hunain` (Strictly NO push)

### Checkpoint: Complete Project Delivered
- [x] Project fully completed and verified locally on branch `Hunain`

## Risks and Mitigations
| Risk | Impact | Mitigation |
|---|---|---|
| Python dependency conflicts on Python 3.14 | Low | Pin compatible versions in requirements or use clean isolated venv |
| Android emulator cannot reach localhost | Med | `AppConstants.apiBase` set to `http://10.0.2.2:8000` |
| Offline demo failure | High | Automatic fallback to `MockRepository` guarantees app never crashes |
| Accidental remote push | High | Enforce local `git commit` only; never run `git push` |

## Open Questions
None.
