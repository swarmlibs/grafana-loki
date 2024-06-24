#!/bin/bash
# Copyright (c) Swarm Library Maintainers.
# SPDX-License-Identifier: MIT

set -e

DOCKERSWARM_STARTUP_DELAY=15

# Docker Swarm service template variables
#  - DOCKERSWARM_SERVICE_ID={{.Service.ID}}
#  - DOCKERSWARM_SERVICE_NAME={{.Service.Name}}
#  - DOCKERSWARM_NODE_ID={{.Node.ID}}
#  - DOCKERSWARM_NODE_HOSTNAME={{.Node.Hostname}}
#  - DOCKERSWARM_TASK_ID={{.Task.ID}}
#  - DOCKERSWARM_TASK_NAME={{.Task.Name}}
#  - DOCKERSWARM_TASK_SLOT={{.Task.Slot}}
#  - DOCKERSWARM_STACK_NAMESPACE={{ index .Service.Labels "com.docker.stack.namespace"}}
export DOCKERSWARM_SERVICE_ID=${DOCKERSWARM_SERVICE_ID}
export DOCKERSWARM_SERVICE_NAME=${DOCKERSWARM_SERVICE_NAME}
export DOCKERSWARM_NODE_ID=${DOCKERSWARM_NODE_ID}
export DOCKERSWARM_NODE_HOSTNAME=${DOCKERSWARM_NODE_HOSTNAME}
export DOCKERSWARM_TASK_ID=${DOCKERSWARM_TASK_ID}
export DOCKERSWARM_TASK_NAME=${DOCKERSWARM_TASK_NAME}
export DOCKERSWARM_TASK_SLOT=${DOCKERSWARM_TASK_SLOT}
export DOCKERSWARM_STACK_NAMESPACE=${DOCKERSWARM_STACK_NAMESPACE}

# Check if any of the variables is empty
if [ -z "$DOCKERSWARM_SERVICE_ID" ] || [ -z "$DOCKERSWARM_SERVICE_NAME" ] || [ -z "$DOCKERSWARM_NODE_ID" ] || [ -z "$DOCKERSWARM_NODE_HOSTNAME" ] || [ -z "$DOCKERSWARM_TASK_ID" ] || [ -z "$DOCKERSWARM_TASK_NAME" ] || [ -z "$DOCKERSWARM_TASK_SLOT" ] || [ -z "$DOCKERSWARM_STACK_NAMESPACE" ]; then
  echo "==> Docker Swarm service template variables:"
  echo "- DOCKERSWARM_SERVICE_ID=${DOCKERSWARM_SERVICE_ID}"
  echo "- DOCKERSWARM_SERVICE_NAME=${DOCKERSWARM_SERVICE_NAME}"
  echo "- DOCKERSWARM_NODE_ID=${DOCKERSWARM_NODE_ID}"
  echo "- DOCKERSWARM_NODE_HOSTNAME=${DOCKERSWARM_NODE_HOSTNAME}"
  echo "- DOCKERSWARM_TASK_ID=${DOCKERSWARM_TASK_ID}"
  echo "- DOCKERSWARM_TASK_NAME=${DOCKERSWARM_TASK_NAME}"
  echo "- DOCKERSWARM_TASK_SLOT=${DOCKERSWARM_TASK_SLOT}"
  echo "- DOCKERSWARM_STACK_NAMESPACE=${DOCKERSWARM_STACK_NAMESPACE}"
  echo "One or more variables is empty. Exiting..."
  exit 1
fi

echo "==> [Docker Swarm Entrypoint] waiting for Docker Swarm to configure the network and DNS resolution... (${DOCKERSWARM_STARTUP_DELAY}s)"
sleep ${DOCKERSWARM_STARTUP_DELAY}

GF_LOKI_CONFIG_FILE="/etc/loki/local-config.yaml"

# -- The log level of the Promtail server
GF_LOKI_LOGLEVEL=${GF_LOKI_LOGLEVEL:-"info"}

# -- The log format of the Promtail server
# Valid formats: `logfmt, json`
GF_LOKI_LOGFORMAT=${GF_LOKI_LOGFORMAT:-"logfmt"}

# The replication factor, which has already been mentioned,
# is how many copies of the log data Loki should make to prevent losing it before flushing to storage.
# We suggest setting this to 3
GF_LOKI_COMMON_STORAGE_RING_REPLICATION_FACTOR=${GF_LOKI_COMMON_STORAGE_RING_REPLICATION_FACTOR:-2}


GF_LOKI_MEMBERLIST_SUBNET=${GF_LOKI_MEMBERLIST_SUBNET:-"10.0.0.0/16"}
GF_LOKI_MEMBERLIST_ADVERTISE_ADDR=$(sockaddr eval 'GetPrivateInterfaces | include "network" "'${GF_LOKI_MEMBERLIST_SUBNET}'" | attr "address"')

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
  replication_factor: ${GF_LOKI_COMMON_STORAGE_RING_REPLICATION_FACTOR}

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
    set -- loki \
      -config.file=${GF_LOKI_CONFIG_FILE} \
      -common.storage.ring.store=memberlist \
      -common.storage.ring.instance-addr="${GF_LOKI_MEMBERLIST_ADVERTISE_ADDR}" \
      -memberlist.advertise-addr="${GF_LOKI_MEMBERLIST_ADVERTISE_ADDR}" \
      -memberlist.join="dns+tasks.${DOCKERSWARM_SERVICE_NAME}:7946" \
      -memberlist.rejoin-interval=30s \
      -memberlist.dead-node-reclaim-time=1m
fi

echo "==> Starting Grafana Loki..."
set -x
exec "$@"
