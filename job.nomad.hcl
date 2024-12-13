job "tiki" {
  type = "service"

  group "tiki" {

    network {
      port "tiki-http" {}
      port "imgproxy-http" {}
    }

    task "tiki" {
      service {
        name = "tiki"
        port = "tiki-http"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.tiki.rule=Host(`tiki.betasektionen.se`)",
          "traefik.http.routers.tiki.tls.certresolver=default",

          "traefik.http.routers.tiki-internal.rule=Host(`tiki.nomad.dsekt.internal`)",
          "traefik.http.routers.tiki-internal.entrypoints=web-internal",
        ]
      }

      driver = "docker"

      config {
        image = var.image.tag
        ports = ["tiki-http"]
      }

      template {
        data        = <<ENV
DATABASE_URL=postgres://tiki:{{ .database_password }}@postgres.dsekt.internal:5432/tiki
SWISH_API_URL={{ .swish_api_url }}
SWISH_CA_CERT={{ .swish_ca_cert }}
SWISH_CERT={{ .swish_cert }}
SWISH_KEY={{ .swish_key }}
SWISH_MERCHANT_NUMBER={{ .swish_merchant_number }}
SWISH_CALLBACK_URL=https://tiki.betasektionen.se/swish/callback
SECRET_KEY_BASE={{ .secret_key_base }}
PHX_HOST=tiki.betasektionen.se
PORT={{ env "NOMAD_PORT_http" }}
STRIPE_API_KEY={{ .stripe_api_key }}
STRIPE_WEBHOOK_SECRET={{ .stripe_webhook_secret }}
OIDC_ISSUER_URL=https://sso.datasektionen.se/op
OIDC_CLIENT_ID={{ .oidc_client_id }}
OIDC_CLIENT_SECRET={{ .oidc_client_secret }}
S3_BUCKET_NAME=tiki
AWS_REGION=eu-north-1
AWS_ACCESS_KEY_ID={{ .aws_access_key_id }}
AWS_SECRET_ACCESS_KEY={{ .aws_secret_access_key }}
IMGPROXY_KEY={{ .imgproxy_key }}
IMGPROXY_SALT={{ .imgproxy_salt }}
IMAGE_FRONTEND_URL=https://imgproxy.tiki.betasektionen.se
                ENV
        destination = "local/.env"
        env         = true
      }
    }


    task "imgproxy" {

      service {
        name = "imgproxy"
        port = "imgproxy-http"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.imgproxy.rule=Host(`imgproxy.tiki.betasektionen.se`)",
          "traefik.http.routers.imgproxy.tls.certresolver=default"
        ]
      }

      driver = "docker"

      config {
        image = "ghcr.io/imgproxy/imgproxy:latest"
        ports = ["imgproxy-http"]
      }


      template {
        data        = <<ENV
IMGPROXY_KEY={{ .imgproxy_key }}
IMGPROXY_SALT={{ .imgproxy_salt }}
AWS_ACCESS_KEY_ID={{ .aws_access_key_id }}
AWS_SECRET_ACCESS_KEY={{ .aws_secret_access_key }}
IMGPROXY_MAX_SRC_RESOLUTION = 30
IMGPROXY_USE_S3 = true
IMGPROXY_TTL = 31536000
AWS_REGION = "eu-north-1"
IMGPROXY_BASE_URL = "s3://tiki"
ENV
        destination = "local/.env"
        env         = true
      }
    }
  }
}

variable "image_tag" {
  type    = string
  default = "ghcr.io/datasektionen/tiki:latest"
}
