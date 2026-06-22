job "tiki-docs" {
  type      = "service"
  namespace = "metaspexet"

  group "tiki-docs" {
    count = 1

    network {
      port "http" {}
    }

    task "tiki-docs" {
      service {
        name     = "tiki-docs"
        port     = "http"
        provider = "nomad"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.tiki-docs.rule=Host(`tiki-docs.datasektionen.se`)",
          "traefik.http.routers.tiki-docs.tls.certresolver=default",
        ]
      }

      driver = "docker"

      config {
        image = var.image_tag
        ports = ["http"]
      }

      template {
        data        = <<EOF
SERVER_PORT={{ env "NOMAD_PORT_http" }}
EOF
        destination = "local/.env"
        env         = true
      }

      resources {
        cpu    = 50
        memory = 32
      }
    }
  }
}

variable "image_tag" {
  type    = string
  default = "ghcr.io/datasektionen/tiki-docs:latest"
}
