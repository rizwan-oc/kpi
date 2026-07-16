import hashlib

from django.core.cache import cache
from django.http import Http404

from allauth.account.internal.decorators import login_not_required
from allauth.socialaccount.adapter import get_adapter
from allauth.socialaccount.models import SocialApp
from allauth.socialaccount.providers.oauth2.views import (
    OAuth2CallbackView,
    OAuth2LoginView,
)
from allauth.socialaccount.providers.openid_connect.views import (
    OpenIDConnectOAuth2Adapter,
)

_DISCOVERY_TTL = 3600  # 1 hour — Keycloak endpoints are stable


class CachingOpenIDConnectAdapter(OpenIDConnectOAuth2Adapter):
    """
    Drop-in replacement for OpenIDConnectOAuth2Adapter that stores the OIDC
    discovery document in Django's cache backend (Redis). The base class caches
    the document only on the adapter instance, which is recreated per request,
    causing one external HTTPS round-trip to Keycloak on every login/ and
    callback/ hit. This subclass promotes that cache to the shared Redis store.
    """

    @property
    def openid_config(self):
        if not hasattr(self, '_openid_config'):
            server_url = self.get_provider().server_url
            key = f'oc:oidc_discovery:{hashlib.md5(server_url.encode()).hexdigest()}'
            config = cache.get(key)
            if config is None:
                # server_url already includes /.well-known/openid-configuration
                # because OpenIDConnectProvider.server_url calls wk_server_url()
                # which appends the suffix automatically (allauth >= 65.x).
                # Do NOT append it again here — that produces a double-suffix URL.
                with get_adapter().get_requests_session() as sess:
                    resp = sess.get(server_url)
                    resp.raise_for_status()
                    config = resp.json()
                cache.set(key, config, _DISCOVERY_TTL)
            self._openid_config = config
        return self._openid_config


@login_not_required
def oidc_login(request, provider_id):
    try:
        view = OAuth2LoginView.adapter_view(
            CachingOpenIDConnectAdapter(request, provider_id)
        )
        return view(request)
    except SocialApp.DoesNotExist:
        raise Http404


@login_not_required
def oidc_callback(request, provider_id):
    try:
        view = OAuth2CallbackView.adapter_view(
            CachingOpenIDConnectAdapter(request, provider_id)
        )
        return view(request)
    except SocialApp.DoesNotExist:
        raise Http404
