# Stage 1: Minify client-side assets
FROM node:20-slim AS build-js

ARG GOPHISH_VERSION=master

RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN git clone --depth 1 --branch ${GOPHISH_VERSION} https://github.com/gophish/gophish.git . \
    || (git clone https://github.com/gophish/gophish.git . && git checkout ${GOPHISH_VERSION})

RUN npm install --only=dev && npx gulp


# Stage 2: Build Go binary with anti-fingerprinting mods
FROM golang:1.22 AS build-go

ARG TRACKING_PARAM=cid

WORKDIR /go/src/github.com/gophish/gophish
COPY --from=build-js /build/ ./

# Anti-fingerprinting: strip GoPhish email headers
RUN sed -i 's/X-Gophish-Contact/X-Contact/g' models/email_request_test.go \
    && sed -i 's/X-Gophish-Contact/X-Contact/g' models/maillog.go \
    && sed -i 's/X-Gophish-Contact/X-Contact/g' models/maillog_test.go \
    && sed -i 's/X-Gophish-Contact/X-Contact/g' models/email_request.go

# Anti-fingerprinting: strip GoPhish webhook signature header
RUN sed -i 's/X-Gophish-Signature/X-Signature/g' webhook/webhook.go

# Anti-fingerprinting: change server name from "gophish" to "IGNORE"
RUN sed -i 's/const ServerName = "gophish"/const ServerName = "IGNORE"/' config/config.go

# Anti-fingerprinting: rename tracking parameter from "rid" to custom value
RUN sed -i "s/const RecipientParameter = \"rid\"/const RecipientParameter = \"${TRACKING_PARAM}\"/g" models/campaign.go

# Custom 404 page (overwrite default)
COPY config/404.html templates/404.html

RUN go build -v -o gophish


# Stage 3: Minimal runtime
FROM debian:bookworm-slim

ARG UID=1000
ARG GID=1000

RUN groupadd -g ${GID} gophish \
    && useradd -m -d /opt/gophish -s /bin/bash -u ${UID} -g ${GID} gophish

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates libsqlite3-0 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/gophish

# Copy binary and assets from build stages
COPY --from=build-go --chown=gophish:gophish /go/src/github.com/gophish/gophish/gophish ./
COPY --from=build-go --chown=gophish:gophish /go/src/github.com/gophish/gophish/db/ ./db/
COPY --from=build-js --chown=gophish:gophish /build/static/js/dist/ ./static/js/dist/
COPY --from=build-js --chown=gophish:gophish /build/static/css/dist/ ./static/css/dist/
COPY --from=build-go --chown=gophish:gophish /go/src/github.com/gophish/gophish/static/images/ ./static/images/
COPY --from=build-go --chown=gophish:gophish /go/src/github.com/gophish/gophish/static/font/ ./static/font/
COPY --from=build-go --chown=gophish:gophish /go/src/github.com/gophish/gophish/templates/ ./templates/

# Copy config
COPY --chown=gophish:gophish config/config.json ./config.json

# Persistent data directory for SQLite
RUN mkdir -p /opt/gophish/data && chown gophish:gophish /opt/gophish/data
VOLUME /opt/gophish/data

# Entrypoint fixes volume ownership (bind/named volumes mount as root:root by
# default on Docker) then drops to the unprivileged gophish user.
RUN apt-get update && apt-get install -y --no-install-recommends gosu \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

EXPOSE 3333 8080

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["./gophish"]
