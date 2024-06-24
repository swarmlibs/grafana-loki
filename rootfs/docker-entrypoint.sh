#!/bin/bash
# Copyright (c) Swarm Library Maintainers.
# SPDX-License-Identifier: MIT

set -e

GF_LOKI_CONFIG_FILE="/etc/loki/local-config.yaml"

# -- The log level of the Promtail server
GF_LOKI_LOGLEVEL=${GF_LOKI_LOGLEVEL:-"info"}

# -- The log format of the Promtail server
# Valid formats: `logfmt, json`
GF_LOKI_LOGFORMAT=${GF_LOKI_LOGFORMAT:-"logfmt"}

# -- Config file contents for Promtail.
echo "Generate configuration file for Grafana Loki..."
mkdir -p $(dirname ${GF_LOKI_CONFIG_FILE})
cat <<EOF >${GF_LOKI_CONFIG_FILE}
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096
  log_level: ${GF_LOKI_LOGLEVEL}
  log_format: ${GF_LOKI_LOGFORMAT}

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

# ruler:
#   alertmanager_url: http://localhost:9093

# By default, Loki will send anonymous, but uniquely-identifiable usage and configuration
# analytics to Grafana Labs. These statistics are sent to https://stats.grafana.org/
#
# Statistics help us better understand how Loki is used, and they show us performance
# levels for most users. This helps us prioritize features and documentation.
# For more information on what's sent, look at
# https://github.com/grafana/loki/blob/main/pkg/analytics/stats.go
# Refer to the buildReport method to see what goes into a report.
#
# If you would like to disable reporting, uncomment the following lines:
analytics:
  reporting_enabled: false
EOF

# If the user is trying to run Prometheus directly with some arguments, then
# pass them to Prometheus.
if [ "${1:0:1}" = '-' ]; then
    set -- loki "$@"
fi

# If the user is trying to run Prometheus directly with out any arguments, then
# pass the configuration file as the first argument.
if [ "$1" = "" ]; then
    set -- loki -config.file=${GF_LOKI_CONFIG_FILE}
fi

echo "==> Starting Grafana Loki..."
set -x
exec "$@"
