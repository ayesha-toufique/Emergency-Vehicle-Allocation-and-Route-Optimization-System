# Spec: Complete Backend Setup, Flutter API Integration & Local Delivery

## Objective
Deliver a complete, functioning emergency route and resource management system (ResQ). Initialize and verify the Django REST backend with SQLite database and synthetic Karachi road grid demo data. Wire the Flutter mobile application's data layer to interface with the Django REST API with automatic offline fallback to local mock data. Verify all algorithm tests and mobile builds, and commit all work locally to branch `Hunain` without pushing to remote.

## Tech Stack
- **Backend**: Python 3.14+, Django 5.1.x, Django REST Framework 3.15.x, SQLite 3 (with MySQL dual-support in settings)
- **Algorithms**: 0/1 Multi-Criteria Knapsack (vehicle allocation), Dynamic Dijkstra (shortest emergency routing), Analytical Hierarchy Process (incident triage)
- **Frontend**: Flutter 3.44.x / Dart 3.12.x
- **VCS**: Git (Local branch `Hunain`, strictly local commits, NO push)

## Commands
```bash
# Backend Setup
cd Backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Database Migrations & Seeding (SQLite mode)
export DB_ENGINE=sqlite
python manage.py migrate
python manage.py seed_demo --allocate

# Backend Automated Tests
python manage.py test algorithms dispatch

# Backend Dev Server
python manage.py runserver 0.0.0.0:8000

# Flutter Frontend Analysis & Build
flutter analyze
flutter test
flutter build apk --release

# Local Version Control
git add .
git commit -m "feat: complete backend initialization and flutter api integration"
```

## Project Structure
```text
.
├── Backend/                 # Django REST Framework backend
│   ├── accounts/            # Custom User model, auth views & tokens
│   ├── algorithms/          # Knapsack allocation & Dijkstra routing algorithms
│   ├── config/              # Django settings, URLs, WSGI
│   ├── dispatch/            # Emergencies, vehicles, allocations, road network
│   ├── manage.py
│   └── requirements.txt
├── lib/                     # Flutter mobile application
│   ├── core/
│   │   ├── constants/       # AppConstants (API endpoints, coords)
│   │   ├── mock/            # MockRepository & demo Karachi data (offline fallback)
│   │   └── services/        # ApiService (HTTP client & network handling)
│   ├── data/
│   │   ├── models/          # Data serialization models
│   │   └── repositories/    # Hybrid repository (API + mock fallback)
│   ├── features/            # Auth, Dispatch, Routing, Admin UI screens
│   └── main.dart
├── tasks/
│   ├── plan.md              # Implementation plan
│   └── todo.md              # Task checklist
└── SPEC.md                  # This specification document
```

## Code Style & Conventions
- **Backend (Python)**: PEP 8 compliant, type hints where appropriate, clean Django CBVs / ViewSets with drf-spectacular documentation.
- **Frontend (Dart)**: Strict analysis adherence (`analysis_options.yaml`), repository pattern with clear separation of network layer and UI state.
- **Error Handling**: Graceful network failure capture; Flutter HTTP client automatically falls back to `MockRepository` when backend is unreachable, logging clear diagnostic warnings rather than crashing.

```dart
// Example: Safe API invocation with Mock fallback
Future<List<Vehicle>> getAvailableVehicles() async {
  try {
    final response = await _http.get(Uri.parse('${AppConstants.apiBase}${AppConstants.endpointVehicles}'));
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List).map((e) => Vehicle.fromJson(e)).toList();
    }
  } catch (e) {
    debugPrint('Backend unreachable, falling back to mock data: $e');
  }
  return _mockRepository.getAvailableVehicles();
}
```

## Testing Strategy
1. **Backend Unit & Algorithm Tests**:
   - `python manage.py test algorithms` verifies Knapsack resource allocation fairness and Dijkstra dynamic path recalculation against synthetic Karachi graph.
   - `python manage.py test dispatch` verifies emergency dispatch lifecycle, user permissions, and REST endpoints.
2. **Frontend Analysis**:
   - `flutter analyze` must pass with zero issues.
3. **Build Verification**:
   - `flutter build apk --release` completes successfully.

## Boundaries
- **Always**:
  - Run backend tests and `flutter analyze` before making commits.
  - Maintain offline mock fallback so mobile app operates whether backend server is online or offline.
  - Work solely on branch `Hunain`.
- **Ask first**:
  - Before modifying existing database models or breaking REST contract schemas.
- **Never**:
  - Run `git push` under ANY circumstances (user constraint: strictly commit only, no push).
  - Delete or bypass failing tests.
  - Commit Python venv or build output binaries to git.

## Success Criteria
1. Python venv created at `Backend/.venv` with all requirements installed cleanly.
2. Django database initialized with SQLite engine and all migrations applied.
3. Synthetic Karachi road network, demo accounts, and vehicles seeded via `seed_demo --allocate`.
4. All Django algorithm and dispatch automated tests pass (`OK`).
5. Flutter HTTP API service implemented with automatic offline fallback to `MockRepository`.
6. `flutter analyze` passes with 0 issues.
7. Changes committed to local git branch `Hunain` with descriptive conventional commits.
8. No git push executed.

## Open Questions
- None. Requirements, database choice (SQLite), fallback strategy, and no-push constraint are established.
