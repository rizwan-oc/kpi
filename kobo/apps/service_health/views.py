# coding: utf-8
import time
from typing import Callable, Optional, Tuple

from django.conf import settings
from django.core.cache import cache
from django.http import HttpResponse

from kobo.apps.openrosa.apps.main.models.user_profile import UserProfile
from kobo.celery import celery_app
from kpi.models import Asset
from kpi.utils.log import logging


def check_status(
    service_name: str, check_function: Callable
) -> Tuple[Optional[str], float]:
    """
    Check service via callable function.
    If an exception is raised, return the class name for public consumption.
    Log the full exception information. This prevents information leakage
    """
    error = None
    t0 = time.time()
    try:
        check_function()
    except Exception as exception:
        logging.error(f'Service health {service_name} check failure', exc_info=True)
        error = repr(type(exception).__name__)
    cache_time = time.time() - t0
    return error, cache_time


def service_health(request):
    """
    Return a HTTP 200 if some very basic runtime tests of the application
    pass. Otherwise, return HTTP 500
    """
    # OpenClinica customization: skip MongoDB check when MONGO_DB_URL is not
    # configured — avoids connection-timeout error spam when MongoDB is not
    # deployed. When configured, failures are non-fatal and only reported on
    # success.
    mongo_message = None
    mongo_time = 0.0
    if settings.MONGO_CONFIGURED:
        t0 = time.time()
        try:
            settings.MONGO_DB.instances.find_one(max_time_ms=settings.MONGO_TIMEOUT_MS)
        except Exception:
            logging.error('Service health Mongo check failure', exc_info=True)
        else:
            mongo_message = 'OK'
        mongo_time = time.time() - t0

    # OpenClinica customization: the external Enketo HTTP probe and Enketo Redis
    # are intentionally omitted — enketo runs externally and its Redis is not
    # reachable from KPI pods. KoBoCAT is integrated as OpenRosa (no separate
    # web app); its DB is checked via 'Postgres kobocat' below.
    all_checks = {
        'Postgres kpi': lambda: Asset.objects.order_by().exists(),
        'Postgres kobocat': lambda: UserProfile.objects.exists(),
        'Cache': lambda: cache.set('a', True, 1),
        'Broker': lambda: celery_app.backend.client.ping(),
        'Session': lambda: request.session.save(),
    }

    check_results = []
    any_failure = False
    for service_name, check_function in all_checks.items():
        service_message, service_time = check_status(service_name, check_function)
        any_failure = True if service_message else any_failure
        check_results.append(
            f"{service_name}: {service_message or 'OK'} in {service_time:.3} seconds"
        )

    output = f"{'FAIL' if any_failure else 'OK'} KPI\r\n\r\n"
    output += '\r\n'.join(check_results)

    if mongo_message is not None:
        output += '\r\nMongo: {} in {:.3} seconds'.format(mongo_message, mongo_time)

    return HttpResponse(
        output, status=(500 if any_failure else 200), content_type='text/plain'
    )
