ARG GRAFANA_LOKI_VERSION=latest
FROM swarmlibs/go-sockaddr:main as go-sockaddr
FROM grafana/loki:${GRAFANA_LOKI_VERSION}
USER root
RUN apk add --no-cache bash ca-certificates
ADD rootfs /
ENTRYPOINT [ "/docker-entrypoint.sh" ]
VOLUME [ "/loki" ]

COPY --from=go-sockaddr /sockaddr /usr/local/bin/sockaddr
