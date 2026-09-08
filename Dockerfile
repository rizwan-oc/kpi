# syntax=docker/dockerfile:labs
# ^  Tell BuildKit to pull the latest 'labs' version
#    of the Dockerfile syntax before the build.
#    -  Access newer BuildKit syntax features, e.g. `COPY --parents`
#      https://docs.docker.com/build/buildkit/frontend/#dockerfile-frontend
#    - Improve compatibility for CI runners, which might be
#      running a slightly older version of docker.

#########################################
# The Dockerfile has 4 stages now:      #
#  1. 📦 Node 'npm-install'             #
#  2. 🛠️ Node 'webpack-build-prod'      #
#  3. 🐍 Python 'pip-dependencies'      #
#  4. 🧰 KPI production image 'kpi-app' #
#########################################

# If you update a base image, make sure to update the
# runners in .github/workflows/ to the corresponding
# Ubuntu version.


#########################
#                       #
# 📦 Node 'npm-install' #
#                       #
#########################

FROM node:20.19-bookworm-slim AS npm-install
WORKDIR /srv/src/kpi

# OC fork: git + CA certs so `npm clean-install` can fetch the private
# @openclinica/logic-builder git dependency (the slim image ships neither).
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# This is our non-root user 1000.
RUN chown node:node .

# Icon source files are in their own layer
#  because they're less commonly updated.
COPY --chown=node:node --parents \
    jsapp/k-icons-css-template.hbs \
    jsapp/svg-icons/ \
    .

# Copy all sources from the build context
# that would affect the outcome of 'npm clean-install'.
COPY --chown=node:node --parents \
    patches/                  \
    scripts/copy_fonts.sh     \
    scripts/generate_icons.js \
    scripts/hints.js          \
    .browserslistrc    \
    package.json       \
    package-lock.json  \
    .

# Run npm clean-install as non-root user,
# and clean the cache for space.
USER node
# OC fork: authenticate the private @openclinica/logic-builder clone with a
# BuildKit secret (Jenkins passes `--secret id=gh_token`). The token is written
# only to a throwaway gitconfig deleted before this layer is committed, so it
# never persists in the image; it rewrites the lockfile's git+ssh URL to
# token-authenticated HTTPS. The final `test -d` fails the build if the real
# package didn't install — so an image can never silently ship without it.
RUN --mount=type=secret,id=gh_token,uid=1000 \
    export GIT_CONFIG_GLOBAL=/tmp/gitconfig \
    && git config --global url."https://x-access-token:$(cat /run/secrets/gh_token)@github.com/".insteadOf "ssh://git@github.com/" \
    && npm clean-install \
    && npm cache clean --force \
    && rm -f /tmp/gitconfig \
    && test -d node_modules/@openclinica/logic-builder/dist

# Results in /srv/src/kpi/:
#   All the sources copied above, plus the generated:
#   + jsapp/fonts/
#   + msw-mocks/
#   + node_modules/

################################
#                              #
# 🛠️ Node 'webpack-build-prod' #
#                              #
################################
FROM node:20.19-bookworm-slim AS webpack-build-prod
WORKDIR /srv/src/kpi
RUN chown node:node .

# Copy inputs from the 'npm-install' stage.
# (These were generated during post-install.)
COPY --from=npm-install --parents \
    /srv/src/kpi/./jsapp/fonts/   \
    /srv/src/kpi/./msw-mocks/     \
    .

# Copy other webpack build inputs from the
# build context.
COPY --chown=node:node --parents \
    jsapp/            \
    patches/          \
    scripts/          \
    webpack/          \
    .babelrc.json     \
    .browserslistrc   \
    .gitignore        \
    .node-version     \
    .nvmrc            \
    .swcrc            \
    orval.config.js   \
    package.json      \
    package-lock.json \
    tsconfig.json     \
    .

# We now have everything we need in /src/srv/kpi/ to
# build the prod webpack app now, except for node_modules.

# For node_modules, we can bind mount it from the 'npm-install'
# stage instead of copying. (This avoids creating another
# 0.6 GB layer in this stage.)

# Build the prod app (as non-root user)
USER node
RUN --mount=from=npm-install,source=/srv/src/kpi/node_modules,target=/srv/src/kpi/node_modules \
    SKIP_TS_CHECK=true          \
    ./node_modules/.bin/webpack \
    --config webpack/prod.config.js

# Results in /srv/src/kpi/:
#   All source files copied above, plus the generated:
#   + jsapp/compiled/*
#   + webpack-stats.json



################################
#                              #
# 🐍 Python 'pip-dependencies' #
#                              #
################################
FROM --platform=$BUILDPLATFORM ghcr.io/astral-sh/uv:python3.10-bookworm AS pip-dependencies
ENV TMP_DIR=/srv/tmp \
    VIRTUAL_ENV=/opt/venv
RUN python -m venv "$VIRTUAL_ENV"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

COPY ./dependencies/pip/requirements.txt "${TMP_DIR}/pip_dependencies.txt"
RUN uv pip sync "${TMP_DIR}/pip_dependencies.txt" 1>/dev/null

# OC fork (OC-28277): install the PRIVATE oc-logic-builder-server package (the
# AI generate-expression endpoint: prompt assembly + Anthropic call). Same
# BuildKit secret as the npm stage, and the same throwaway-credential trick:
# the token rides a netrc deleted inside this RUN, so it stays out of the URL,
# out of argv, and out of the layer command `docker history` keeps — which
# records the literal `$(cat …)`, never its value. github.com answers the
# archive with a redirect to a self-authenticating codeload URL, so a netrc
# entry for github.com alone is enough. --no-deps is safe ONLY because the
# `uv pip sync` above has already installed its one runtime dep, requests.
# The import check is load-bearing: a package that installs but cannot import is
# a BOOT failure, not a missing feature. router_api_v2 calls find_spec on the
# .django submodule, which imports the parent package, whose own chain reaches
# `import requests` — and that raise happens at URLconf import time, killing
# every request. Fail the build here instead. Pinned by git sha, not dist version.
ARG LOGIC_BUILDER_SERVER_REF=4309f972f5b89a1d1e8b249547e7d51119d6e2ee
RUN --mount=type=secret,id=gh_token \
    printf 'machine github.com\nlogin x-access-token\npassword %s\n' \
      "$(cat /run/secrets/gh_token)" > /tmp/netrc \
    && NETRC=/tmp/netrc uv pip install --no-deps \
      "oc-logic-builder-server @ https://github.com/OpenClinica/logic-builder/archive/${LOGIC_BUILDER_SERVER_REF}.tar.gz#subdirectory=server" \
    && rm -f /tmp/netrc \
    && python -c "import oc_logic_builder_server"

RUN rm -rf ${VIRTUAL_ENV}/lib/python*/site-packages/rest_framework/static/rest_framework

#####################################
#                                   #
# 🧰 KPI production image 'kpi-app' #
#                                   #
#####################################
FROM --platform=$TARGETPLATFORM ghcr.io/astral-sh/uv:python3.10-bookworm-slim AS kpi-app

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

###########################
# Install `apt` packages. #
###########################

# DO NOT remove packages like `less` and `procps` without approval from
# jnm (or the current on-call sysadmin). Thanks.
RUN apt-get -qq update && \
    apt-get -qq -y install curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get -qq -y install --no-install-recommends \
        ffmpeg \
        gdal-bin \
        gettext \
        git \
        gosu \
        less \
        libproj-dev \
        locales \
        # pin an exact Node version for stability. update this regularly.
        nodejs=$(apt-cache show nodejs | grep -F 'Version: 20.18.1' | cut -f 2 -d ' ') \
        openjdk-17-jre \
        postgresql-client \
        procps \
        rsync \
        vim-tiny \
        wait-for-it && \
    apt-get clean && \
        rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

####################
# Install locales. #
####################

RUN echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && \
    locale-gen && dpkg-reconfigure locales -f noninteractive

##########################################
# Set environment variables and workdir. #
##########################################

# Note: NGINX_STATIC_DIR is the mountpoint of a volume
#    shared with the `nginx` container.
#    Static files will be copied there.
ENV DJANGO_SETTINGS_MODULE=kobo.settings.prod \
    INIT_PATH=/srv/init                       \
    KPI_LOGS_DIR=/srv/logs                    \
    KPI_MEDIA_DIR=/srv/src/kpi/media          \
    KPI_NODE_PATH=/srv/src/kpi/node_modules   \
    KPI_SRC_DIR=/srv/src/kpi                  \
    NGINX_STATIC_DIR=/srv/static              \
    OPENROSA_MEDIA_DIR=/srv/src/kobocat/media \
    TMP_DIR=/srv/tmp                          \
    UWSGI_USER=kobo                           \
    UWSGI_GROUP=kobo                          \
    VIRTUAL_ENV=/opt/venv

WORKDIR ${KPI_SRC_DIR}/

####################################
# Create local non-root user 1000  #
####################################
RUN adduser --disabled-password --gecos '' "$UWSGI_USER"

#################################################
# Set up Node for kobo-docker lifecycle scripts #
#   (see ./docker/entrypoint.sh)                #
#################################################
RUN mkdir -p "${TMP_DIR}/.npm" && \
    npm config set cache "${TMP_DIR}/.npm" --global && \
    npm install --global --production github:mgol/check-dependencies#bfc3d06ba7d52b5ea9770f708d882526488eeb7d && \
    npm cache clean --force

###############################################
# Copy sources from context and build stages. #
###############################################

# Copy KPI directory from build context.
COPY . "${KPI_SRC_DIR}"

# Copy virtualenv from 'pip-dependencies'.
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
COPY --from=pip-dependencies "$VIRTUAL_ENV" "$VIRTUAL_ENV"

# OC fork (OC-28277): carry the sync marker over too. docker/entrypoint.sh
# re-runs `uv pip sync` at startup whenever this file differs from
# requirements.txt, and an ABSENT marker counts as differing — which would
# uninstall oc-logic-builder-server (deliberately not in requirements.txt) on
# every container start and silently 404 the AI endpoint. Both copies come from
# the same build context, so they match and the startup sync is skipped, which
# is what upstream's marker was for.
COPY --from=pip-dependencies "${TMP_DIR}/pip_dependencies.txt" "${TMP_DIR}/pip_dependencies.txt"

# Copy static production build from 'webpack-build-prod'.
COPY --from=webpack-build-prod --parents \
    ${KPI_SRC_DIR}/./jsapp/compiled/     \
    ${KPI_SRC_DIR}/./webpack-stats.json  \
    .
###########################
# Organize static assets. #
###########################
RUN python manage.py collectstatic --noinput --ignore rest_framework

######################################
# Retrieve and compile translations. #
######################################
RUN git submodule init && \
    git submodule update --remote && \
    python manage.py compilemessages

##########################################
# Persist the log and email directories. #
##########################################
RUN mkdir -p \
    "${KPI_LOGS_DIR}/" \
    "${KPI_SRC_DIR}/emails"

#################################################
# Handle runtime tasks and create main process. #
#################################################

# Using `/etc/profile.d/` as a repository for non-hard-coded environment variable overrides.
RUN echo "export PATH=${PATH}" >> /etc/profile && \
    echo 'source /etc/profile' >> /root/.bashrc && \
    echo 'source /etc/profile' >> /home/${UWSGI_USER}/.bashrc

# Add/Restore `UWSGI_USER`'s permissions
# chown of `${TMP_DIR}/.npm` is a hack needed for kobo-install-based staging deployments;
# see internal discussion at https://chat.kobotoolbox.org/#narrow/stream/4-Kobo-Dev/topic/Unu.2C.20du.2C.20tri.2C.20kvar.20deployments/near/322075
RUN chown -R "${UWSGI_USER}:${UWSGI_GROUP}" ${KPI_SRC_DIR}/emails/ && \
    chown -R "${UWSGI_USER}:${UWSGI_GROUP}" ${KPI_LOGS_DIR} && \
    chown -R "${UWSGI_USER}:${UWSGI_GROUP}" ${TMP_DIR} && \
    chown -R root:root "${TMP_DIR}/.npm"

# ##############################################################
# # TMP 2026/01/29 - kpi#6498                                  #
# #   Retain a copy of node_modules in the KPI container,      #
# #   so that people don't have to update their workflows yet. #
# ##############################################################
COPY --from=npm-install --parents \
    /srv/src/kpi/./node_modules/  \
    .
# ##############################################################

# Add node_modules/.bin to PATH,
# in case scripts are relying on it.
ENV PATH=$PATH:${KPI_NODE_PATH}/.bin

EXPOSE 8000

CMD ["/bin/bash", "docker/entrypoint.sh"]
