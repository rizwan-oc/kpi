# coding: utf-8
import os

# Dummy Keycloak values so base.py's env.str() calls don't crash during tests.
# CI doesn't set these; setdefault() lets real env vars override if present.
os.environ.setdefault('KEYCLOAK_AUTH_URI', 'https://auth.test.example.com')
os.environ.setdefault('KEYCLOAK_DEFAULT_REALM', 'test-realm')
os.environ.setdefault('KEYCLOAK_CLIENT_SECRET', 'test-client-secret')
os.environ.setdefault('KEYCLOAK_ADMIN_CLIENT_SECRET', 'test-admin-client-secret')

from django.contrib.auth.management import DEFAULT_DB_ALIAS  # noqa: E402
from mongomock import MongoClient as MockMongoClient  # noqa: E402

from .base import *  # noqa: E402, F403

# For tests, don't use KoboCAT's DB
DATABASES = {
    'default': env.db_url(
        'KPI_DATABASE_URL'
        if 'KPI_DATABASE_URL' in os.environ
        else 'DATABASE_URL',
        default='sqlite:///%s/db.sqlite3' % BASE_DIR,
    ),
}

DATABASE_ROUTERS = ['kpi.db_routers.TestingDatabaseRouter']

TESTING = True

# Decrease prod value to speed-up tests
DEFAULT_API_PAGE_SIZE = 50
MAX_API_PAGE_SIZE = 100

ENV = 'testing'

# Run all Celery tasks synchronously during testing
CELERY_TASK_ALWAYS_EAGER = True

MONGO_CONNECTION_URL = 'mongodb://fakehost/formhub_test'
mongo_client = MockMongoClient(
    MONGO_CONNECTION_URL, connect=False, journal=True, tz_aware=True
)
MONGO_DB = mongo_client['formhub_test']

ENKETO_URL = 'http://enketo.mock'
ENKETO_INTERNAL_URL = 'http://enketo.mock'

# Do not use cache with Constance in tests to avoid overwriting production
# cached values
CONSTANCE_DATABASE_CACHE_BACKEND = None

# Enable i18n in tests so that translation.override() works correctly;
# base.py sets USE_I18N=False for production performance reasons.
USE_I18N = True

if 'djstripe' not in INSTALLED_APPS:  # noqa F405
    INSTALLED_APPS += ('djstripe', 'kobo.apps.stripe')  # noqa F405
STRIPE_ENABLED = True

WEBPACK_LOADER['DEFAULT'][
    'LOADER_CLASS'
] = 'webpack_loader.loader.FakeWebpackLoader'

# KoboCAT settings
TEST_HTTP_HOST = 'testserver'
TEST_USERNAME = 'bob'

SKIP_TESTS_WITH_CONCURRENCY = os.getenv('SKIP_TESTS_WITH_CONCURRENCY', False)

OPENROSA_DB_ALIAS = DEFAULT_DB_ALIAS
MASS_EMAILS_CONDENSE_SEND = False

# mock AWS creds
# TODO: remove when we stop using Django settings for bedrock access
AWS_ACCESS_KEY_ID = ''
AWS_SECRET_ACCESS_KEY = ''
AWS_BEDROCK_REGION_NAME = ''
ATTACHMENT_XPATHS_CACHE_TTL = 60

GS_BUCKET_NAME = 'test_bucket'

# Use a fast password hasher in tests — the default PBKDF2 hasher, used in production,
# is intentionally slow (security feature) and causes significant test overhead.
# MD5 is used here ONLY for tests to speed them up. It must NEVER be used in production.
PASSWORD_HASHERS = [
    'django.contrib.auth.hashers.MD5PasswordHasher',
]
