FROM debian:unstable-slim

ENTRYPOINT ["/usr/bin/tini","--","/usr/local/searxng/dockerfiles/docker-entrypoint.sh"]
EXPOSE 8080
VOLUME /etc/searxng
VOLUME /huggingface

RUN mkdir /huggingface
RUN mkdir /usr/local/searxng
WORKDIR /usr/local/searxng

# stuff to be cached:
RUN apt update && apt install -y python3 python3-pip \
  python3-dev python3-babel uwsgi uwsgi-plugin-python3 tini \
  git build-essential libxslt-dev zlib1g-dev libffi-dev libssl-dev brotli
RUN pip3 install --break-system-packages setuptools wheel pyyaml

COPY requirements.txt ./requirements.txt
RUN pip3 install --break-system-packages -r requirements.txt

# ----

ARG GID=1000
ARG UID=1000

RUN groupadd --gid $GID searxng \
 && useradd --uid $UID --gid $GID --shell /bin/bash --system \
    --home-dir "/usr/local/searxng" searxng
RUN echo 'nonroot ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

RUN chown -R searxng:searxng /huggingface
RUN chmod 666 /huggingface
RUN chown -R searxng:searxng /usr/local/searxng

COPY --chown=searxng:searxng dockerfiles ./dockerfiles
COPY --chown=searxng:searxng searx ./searx

ENV HF_HOME=/huggingface

ENV INSTANCE_NAME=searxng \
    AUTOCOMPLETE= \
    BASE_URL= \
    MORTY_KEY= \
    MORTY_URL= \
    SEARXNG_SETTINGS_PATH=/usr/local/searxng/settings.yml \
    UWSGI_SETTINGS_PATH=/usr/local/searxng/uwsgi.ini \
    UWSGI_WORKERS=1 \
    UWSGI_THREADS=4

ARG TIMESTAMP_SETTINGS=0
ARG TIMESTAMP_UWSGI=0
ARG VERSION_GITCOMMIT=unknown

RUN su searxng -c "/usr/bin/python3 -m compileall -q searx" \
 && touch -c --date=@${TIMESTAMP_SETTINGS} searx/settings.yml \
 && touch -c --date=@${TIMESTAMP_UWSGI} dockerfiles/uwsgi.ini \
 && find /usr/local/searxng/searx/static \( -name '*.html' -o -name '*.css' -o -name '*.js' \
    -o -name '*.svg' -o -name '*.ttf' -o -name '*.eot' \) \
    -type f -exec gzip -f -9 -k {} \+ -exec brotli --best {} \+
