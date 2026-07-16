import logging
from urllib.parse import urlencode

from django.contrib.auth import logout

LOGGER = logging.getLogger(__name__)


class SDUserSwitchMiddleware:
    """
    Detects when the SD (wekan-oc) user differs from the active FD Django session
    and forces OIDC re-authentication. SD passes ?oc_sd_user=<username> in the
    iframe URL (set in formDesignerUrl() in
    wekan-oc/client/components/boards/boardBody.js).
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        sd_user = request.GET.get('oc_sd_user')
        if sd_user and request.user.is_authenticated:
            # Derive base username from the Django user object (always available
            # for authenticated users). The stored session key is used as a
            # fallback but may be absent for sessions created before this feature.
            fd_base = (
                request.session.get('oc_fd_base_username')
                or request.user.username.rsplit('+', 1)[0]
            )
            if fd_base != sd_user:
                LOGGER.info(
                    'SDUserSwitch: SD user %s != FD user %s — forcing OIDC re-auth',
                    sd_user,
                    fd_base,
                )
                logout(request)
                from django.shortcuts import redirect

                next_qs = urlencode({'next': request.get_full_path()})
                return redirect(f'/accounts/oidc/keycloak/login/?{next_qs}')
        return self.get_response(request)
