import json
import os
from urllib.parse import urlencode

from django.conf import settings
from django.contrib import auth
from django.http import (
    HttpResponseNotAllowed,
    HttpResponseNotFound,
    HttpResponseRedirect,
    JsonResponse,
)
from django.urls import reverse
from django.utils.module_loading import import_string
from django.views.decorators.csrf import csrf_exempt
from django.views.generic import View


class OCAuthenticationCallbackView(View):
    """Legacy OIDC callback stub.

    Allauth now handles OIDC at /accounts/oidc/keycloak/login/callback/.
    Keycloak's Valid Redirect URIs must be updated to that URL.
    Until then, this view redirects to the allauth login initiation.
    """
    http_method_names = ['get']

    def get(self, request):
        return HttpResponseRedirect(
            reverse('openid_connect_login', kwargs={'provider_id': 'keycloak'})
        )


class OCAuthenticationRequestView(View):
    """Initiates OIDC authentication via allauth's OpenID Connect provider."""
    http_method_names = ['get']

    def get(self, request):
        login_url = reverse('openid_connect_login', kwargs={'provider_id': 'keycloak'})
        next_url = request.GET.get('next', '')
        if next_url:
            login_url = f'{login_url}?{urlencode({"next": next_url})}'
        return HttpResponseRedirect(login_url)


class OCLogoutView(View):
    """Logout helper view"""
    http_method_names = ['get', 'post']

    @property
    def redirect_url(self):
        return getattr(settings, 'LOGOUT_REDIRECT_URL', '/')

    def post(self, request):
        logout_url = self.redirect_url

        if request.user.is_authenticated:
            logout_from_op = getattr(settings, 'OIDC_OP_LOGOUT_URL_METHOD', '')
            if logout_from_op:
                logout_url = import_string(logout_from_op)(request)
            auth.logout(request)

        return HttpResponseRedirect(logout_url)

    def get(self, request):
        if getattr(settings, 'ALLOW_LOGOUT_GET_METHOD', False):
            return self.post(request)
        return HttpResponseNotAllowed(['POST'])


class OCAppInfoView(View):

    http_method_names = ['get']

    @csrf_exempt
    def get(self, request):
        package_info = {}
        try:
            config_file = os.path.join(settings.BASE_DIR, 'package.json')
            with open(config_file, 'r') as f:
                package_info = json.loads(f.read())
        except IOError:
            return HttpResponseNotFound()

        kpi_data = {
            'name': package_info['name'],
            'description': package_info['description'],
            'version': package_info['version'],
            'status': 'passing',
        }

        return JsonResponse([kpi_data], safe=False)
