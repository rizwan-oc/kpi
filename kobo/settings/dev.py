# coding: utf-8
from .base import *

LOGGING['handlers']['console'] = {
    'level': 'DEBUG',
    'class': 'logging.StreamHandler',
    'formatter': 'verbose'
}

INSTALLED_APPS = INSTALLED_APPS + ('debug_toolbar',)
MIDDLEWARE.append('debug_toolbar.middleware.DebugToolbarMiddleware')


def show_toolbar(request):
    return env.bool('DEBUG_TOOLBAR', False)


DEBUG_TOOLBAR_CONFIG = {'SHOW_TOOLBAR_CALLBACK': show_toolbar}

ENV = 'dev'

# Expiration time in sec. after which paired data xml file must be regenerated
PAIRED_DATA_EXPIRATION = 5
PAIRED_DATA_REGEN_LOCK_TIMEOUT = 10  # seconds

CALCULATED_HASH_CACHE_EXPIRATION = 5

# To avoid buffer to be truncated when running `runserver_plus` or `shell_plus`
# with option `--print-sql`
SHELL_PLUS_PRINT_SQL_TRUNCATE = None
RUNSERVER_PLUS_PRINT_SQL_TRUNCATE = None

# local development: disable secure cookies when not effectively serving over HTTPS
if not COOKIES_ARE_SECURE:
    SESSION_COOKIE_SECURE = False
    CSRF_COOKIE_SECURE = False
    SESSION_COOKIE_SAMESITE = False
    CSRF_COOKIE_SAMESITE = False
    ALLOWED_HOSTS = '*'
