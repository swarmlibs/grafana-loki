variable "GRAFANA_LOKI_VERSION" { default = "latest" }

target "docker-metadata-action" {}
target "github-metadata-action" {}

target "default" {
    inherits = [ "grafana-loki" ]
    platforms = [
        "linux/amd64",
        "linux/arm64"
    ]
}

target "local" {
    inherits = [ "grafana-loki" ]
    tags = [ "swarmlibs/grafana-loki:local" ]
}

target "grafana-loki" {
    context = "."
    dockerfile = "Dockerfile"
    inherits = [
        "docker-metadata-action",
        "github-metadata-action",
    ]
    args = {
        GRAFANA_LOKI_VERSION = "${GRAFANA_LOKI_VERSION}"
    }
}
