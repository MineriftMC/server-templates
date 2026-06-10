FROM eclipse-temurin:25

ARG PAPER_VERSION=26.1.2
# always use the latest paper build
ARG PAPER_BUILDS_JSON=https://fill.papermc.io/v3/projects/paper/versions/${PAPER_VERSION}/builds/latest

# hard coding viaversion and viabackwards from modrinth is not a good idea
# copied it from https://forge.techtransthai.org/AeroSMP/Pterodactyl-Eggs
ARG JENKINS_VIAVERSION_JSON=https://ci.viaversion.com/job/ViaVersion/lastSuccessfulBuild/api/json
ARG JENKINS_VIABACKWARDS_JSON=https://ci.viaversion.com/job/ViaBackwards/lastSuccessfulBuild/api/json

# fawe
ARG JENKINS_FAWE_JSON=https://ci.athion.net/job/FastAsyncWorldEdit/lastSuccessfulBuild/api/json

ENV DATA_DIR=/data
ENV PAPER_JAR_NAME=paper.jar
ENV SERVER_MEMORY=2G
ENV JAVA_MIN_MEMORY=512M
ENV HOME=/data

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl jq python3 tini \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/minerift

RUN mkdir -p /opt/minerift/plugins /opt/minerift/bin
RUN groupadd --gid 1000 minerift \
    && useradd --uid 1000 --gid 1000 --home-dir /data --no-create-home --shell /usr/sbin/nologin minerift \
    && chown -R 1000:1000 /opt/minerift

RUN PAPER_BUILD_JSON="$(curl -fsSL -A "minerift-docker-build" "${PAPER_BUILDS_JSON}")" \
    && PAPER_DOWNLOAD_URL="$(printf '%s' "${PAPER_BUILD_JSON}" | jq -r '.downloads["server:default"].url')" \
    && curl -fsSL "${PAPER_DOWNLOAD_URL}" -o "/opt/minerift/paper.jar" \
    && VIAVERSION_JSON="$(curl -fsSL "${JENKINS_VIAVERSION_JSON}")" \
    && VIAVERSION_PATH="$(printf '%s' "${VIAVERSION_JSON}" | jq -r '.artifacts[0].relativePath')" \
    && VIAVERSION_NUMBER="$(printf '%s' "${VIAVERSION_JSON}" | jq -r '.number')" \
    && curl -fsSL "https://ci.viaversion.com/job/ViaVersion/${VIAVERSION_NUMBER}/artifact/${VIAVERSION_PATH}" -o /opt/minerift/plugins/ViaVersion.jar \
    && VIABACKWARDS_JSON="$(curl -fsSL "${JENKINS_VIABACKWARDS_JSON}")" \
    && VIABACKWARDS_PATH="$(printf '%s' "${VIABACKWARDS_JSON}" | jq -r '.artifacts[0].relativePath')" \
    && VIABACKWARDS_NUMBER="$(printf '%s' "${VIABACKWARDS_JSON}" | jq -r '.number')" \
    && curl -fsSL "https://ci.viaversion.com/job/ViaBackwards/${VIABACKWARDS_NUMBER}/artifact/${VIABACKWARDS_PATH}" -o /opt/minerift/plugins/ViaBackwards.jar \
    && FAWE_JSON="$(curl -fsSL "${JENKINS_FAWE_JSON}")" \
    && FAWE_NUMBER="$(printf '%s' "${FAWE_JSON}" | jq -r '.number')" \
    && FAWE_PATH="$(printf '%s' "${FAWE_JSON}" | jq -r '[.artifacts[].relativePath] | map(select(test("-Paper-")))[0]')" \
    && curl -fsSL "https://ci.athion.net/job/FastAsyncWorldEdit/${FAWE_NUMBER}/artifact/${FAWE_PATH}" -o /opt/minerift/plugins/FastAsyncWorldEdit.jar

# also copy files to the server
COPY files/ /opt/minerift/files/
COPY start.sh /opt/minerift/bin/start.sh

RUN chmod +x /opt/minerift/bin/start.sh \
    && printf '#!/usr/bin/env bash\nset -euo pipefail\nprintf "%%s\\n" "$*" > /proc/1/fd/0\n' > /usr/local/bin/mc-send-to-console \
    && chmod +x /usr/local/bin/mc-send-to-console

VOLUME ["/data"]
EXPOSE 25565
USER 1000:1000

ENTRYPOINT ["/usr/bin/tini", "--", "/opt/minerift/bin/start.sh"]
