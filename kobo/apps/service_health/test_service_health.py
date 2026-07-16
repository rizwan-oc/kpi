from unittest.mock import patch

import responses
from django.conf import settings
from django.test import TestCase
from django.urls import reverse


class ServiceHealthTestCase(TestCase):
    url = reverse('service-health')

    @responses.activate
    def test_service_health(self):
        responses.add(responses.GET, settings.ENKETO_INTERNAL_URL, status=200)
        res = self.client.get(self.url)
        self.assertContains(res, 'OK')

    def test_service_health_failure(self):
        # OC's health view does not probe Enketo over HTTP; simulate a failure
        # in the Django cache check instead (one of the OC-checked services).
        with patch(
            'kobo.apps.service_health.views.cache.set',
            side_effect=Exception('cache failure'),
        ):
            res = self.client.get(self.url)
        self.assertContains(res, 'Exception', status_code=500)
