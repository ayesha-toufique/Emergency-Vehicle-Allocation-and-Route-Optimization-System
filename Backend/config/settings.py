"""
Django settings for the ResQ backend.

All environment-specific values are read from environment variables or a
`.env` file in the project root (see .env.example).
"""

import os
import sys
from pathlib import Path

from corsheaders.defaults import default_headers

BASE_DIR = Path(__file__).resolve().parent.parent


def _load_dotenv(path):
    """Minimal .env loader (KEY=VALUE lines) so no extra dependency is needed."""
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


_load_dotenv(BASE_DIR / ".env")


def env(key, default=None):
    return os.environ.get(key, default)


def env_bool(key, default=False):
    return str(env(key, str(default))).strip().lower() in ("1", "true", "yes", "on")


def env_list(key, default=""):
    return [x.strip() for x in str(env(key, default)).split(",") if x.strip()]


SECRET_KEY = env("DJANGO_SECRET_KEY", "dev-only-insecure-key-change-me")
DEBUG = env_bool("DJANGO_DEBUG", True)
TESTING = len(sys.argv) > 1 and sys.argv[1] == "test"

if not DEBUG and (not SECRET_KEY or SECRET_KEY == "dev-only-insecure-key-change-me"):
    from django.core.exceptions import ImproperlyConfigured
    raise ImproperlyConfigured("DJANGO_SECRET_KEY must be configured in production.")

# ---------------------------------------------------------------------------
# Hosts / CSRF (ngrok)
# ---------------------------------------------------------------------------
ALLOWED_HOSTS = env_list(
    "DJANGO_ALLOWED_HOSTS",
    "*",  # fine for development; list real hosts in production
)

# Needed for the Django admin / any session-based POST through ngrok.
CSRF_TRUSTED_ORIGINS = [
    "https://those-commotion-voter.ngrok-free.dev",
    "https://*.ngrok-free.dev",
    "https://*.ngrok-free.app",
] + env_list("CSRF_TRUSTED_ORIGINS", "")

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "rest_framework.authtoken",
    "corsheaders",
    "accounts",
    "dispatch",
    "drf_spectacular",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"

# ---------------------------------------------------------------------------
# Database (MySQL is the project requirement; SQLite only for quick try-outs)
# ---------------------------------------------------------------------------
DB_ENGINE = env("DB_ENGINE", "mysql").lower()
if DB_ENGINE == "sqlite":
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "db.sqlite3",
        }
    }
else:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.mysql",
            "NAME": env("DB_NAME", "resq_db"),
            "USER": env("DB_USER", "resq"),
            "PASSWORD": env("DB_PASSWORD", "NewPass123"),
            "HOST": env("DB_HOST", "127.0.0.1"),
            "PORT": env("DB_PORT", "3306"),
            "OPTIONS": {
                "charset": "utf8mb4",
                "init_command": "SET sql_mode='STRICT_TRANS_TABLES'",
            },
            "TEST": {"NAME": "test_" + env("DB_NAME", "resq_db")},
        }
    }

AUTH_USER_MODEL = "accounts.User"

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
     "OPTIONS": {"min_length": 6}},
]

LANGUAGE_CODE = "en-us"
TIME_ZONE = "Asia/Karachi"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# ---------------------------------------------------------------------------
# REST framework
# ---------------------------------------------------------------------------
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework.authentication.TokenAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticated",
    ],
    "DEFAULT_RENDERER_CLASSES": ["rest_framework.renderers.JSONRenderer"]
    + (["rest_framework.renderers.BrowsableAPIRenderer"] if DEBUG else []),
    "EXCEPTION_HANDLER": "dispatch.exceptions.api_exception_handler",
    "DATETIME_FORMAT": "iso-8601",
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
    ] if not TESTING else [],
    "DEFAULT_THROTTLE_RATES": {
        "anon": "10000/min" if TESTING else env("THROTTLE_ANON_RATE", "120/min"),
        "user": "10000/min" if TESTING else env("THROTTLE_USER_RATE", "600/min"),
        "auth": "10000/min" if TESTING else env("THROTTLE_AUTH_RATE", "30/min"),
    },
}

# ---------------------------------------------------------------------------
# CORS (Flutter web / emulator / friend's frontend through ngrok)
# ---------------------------------------------------------------------------
CORS_ALLOW_ALL_ORIGINS = env_bool("CORS_ALLOW_ALL", DEBUG)
CORS_ALLOWED_ORIGINS = env_list("CORS_ALLOWED_ORIGINS", "")
CORS_ALLOW_HEADERS = list(default_headers) + ["ngrok-skip-browser-warning"]

# ---------------------------------------------------------------------------
# HTTPS & Security Headers (OWASP Hardening).
# ---------------------------------------------------------------------------
# ngrok terminates TLS and forwards plain HTTP, so trust its forwarded header.
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_BROWSER_XSS_FILTER = True
X_FRAME_OPTIONS = "DENY"

if not DEBUG:
    SECURE_SSL_REDIRECT = env_bool("SECURE_SSL_REDIRECT", True)
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SESSION_COOKIE_HTTPONLY = True
    CSRF_COOKIE_HTTPONLY = True
    SECURE_HSTS_SECONDS = int(env("SECURE_HSTS_SECONDS", "31536000"))
    SECURE_HSTS_INCLUDE_SUBDOMAINS = env_bool("SECURE_HSTS_SUBDOMAINS", True)
    SECURE_HSTS_PRELOAD = env_bool("SECURE_HSTS_PRELOAD", True)

# ---------------------------------------------------------------------------
# ResQ planner settings
# ---------------------------------------------------------------------------
RESQ = {
    # Run DP + Dijkstra automatically on new emergency / vehicle free / road block.
    "AUTO_ALLOCATE": env_bool("AUTO_ALLOCATE", True),
    # Vehicles below this fuel level (%) are not dispatched.
    "MIN_FUEL_LEVEL": int(env("MIN_FUEL_LEVEL", "15")),
    # A point farther than this from any road node is treated as off-network.
    "MAX_SNAP_DISTANCE_KM": float(env("MAX_SNAP_DISTANCE_KM", "3")),
    # Speed used for the short connector from a GPS point to the nearest road node.
    "CONNECTOR_SPEED_KMH": float(env("CONNECTOR_SPEED_KMH", "20")),
    # Keep raw vehicle GPS logs for this many days (see `prune_location_logs`).
    "LOCATION_LOG_RETENTION_DAYS": int(env("LOCATION_LOG_RETENTION_DAYS", "30")),
}

TESTING = len(sys.argv) > 1 and sys.argv[1] == "test"
if TESTING:
    # Fast hashing so the test-suite does not spend seconds on PBKDF2.
    PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {"simple": {"format": "%(asctime)s %(levelname)s %(name)s: %(message)s"}},
    "handlers": {"console": {"class": "logging.StreamHandler", "formatter": "simple"}},
    "loggers": {"resq": {"handlers": ["console"], "level": "WARNING" if TESTING else "INFO"}},
}