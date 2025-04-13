job "tiki" {
  type = "service"
  namespace = "metaspexet"

  group "tiki" {

    network {
      port "tikihttp" {}
      port "imgproxyhttp" {}
    }

    task "tiki" {
      service {
        name     = "tiki"
        port     = "tikihttp"
        provider = "nomad"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.tiki.rule=Host(`tiki.datasektionen.se`)",
          "traefik.http.routers.tiki.tls.certresolver=default",

          "traefik.http.routers.tiki-internal.rule=Host(`tiki.nomad.dsekt.internal`)",
          "traefik.http.routers.tiki-internal.entrypoints=web-internal",
        ]
      }

      driver = "docker"

      config {
        image = var.image_tag
        ports = ["tikihttp"]
      }

      template {

        data        = <<EOF
{{ with nomadVar "nomad/jobs/tiki" }}
DATABASE_URL=postgres://tiki:{{ .database_password }}@postgres.dsekt.internal:5432/tiki
SWISH_API_URL=https://staging.getswish.pub.tds.tieto.com/swish-cpcapi/api
SWISH_CERT={{ .swish_cert }}
SWISH_KEY={{ .swish_key }}
SWISH_MERCHANT_NUMBER={{ .swish_merchant_number }}
SWISH_CALLBACK_URL=https://tiki.datasektionen.se/swish/callback
SECRET_KEY_BASE={{ .secret_key_base }}
PHX_HOST=tiki.datasektionen.se
PORT={{ env "NOMAD_PORT_tikihttp" }}
SPAM_API_KEY={{ .spam_api_key }}
STRIPE_API_KEY={{ .stripe_api_key }}
STRIPE_PUBLIC_KEY={{ .stripe_public_key }}
STRIPE_WEBHOOK_SECRET={{ .stripe_webhook_secret }}
OIDC_ISSUER_URL=https://sso.datasektionen.se/op
OIDC_CLIENT_ID={{ .oidc_client_id }}
OIDC_CLIENT_SECRET={{ .oidc_client_secret }}
S3_BUCKET_NAME=dsekt-tiki
AWS_REGION="eu-north-1"
AWS_ACCESS_KEY_ID={{ .aws_access_key_id }}
AWS_SECRET_ACCESS_KEY={{ .aws_secret_access_key }}
IMGPROXY_KEY={{ .imgproxy_key }}
IMGPROXY_SALT={{ .imgproxy_salt }}
IMAGE_FRONTEND_URL=https://dnok4ulql7gij.cloudfront.net
{{ end }}
EOF
        destination = "local/.env"
        env         = true
      }

      resources {
        cpu    = 512
        memory = 1024
      }
    }


    task "imgproxy" {

      service {
        name     = "imgproxy"
        port     = "imgproxyhttp"
        provider = "nomad"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.tiki-imgproxy.rule=Host(`tiki-imgproxy.datasektionen.se`)",
          "traefik.http.routers.tiki-imgproxy.tls.certresolver=default"
        ]
      }

      driver = "docker"

      config {
        image = "ghcr.io/imgproxy/imgproxy:latest"
        ports = ["imgproxyhttp"]
      }


      template {
        data        = <<EOF
{{ with nomadVar "nomad/jobs/tiki" }}
IMGPROXY_KEY={{ .imgproxy_key }}
IMGPROXY_SALT={{ .imgproxy_salt }}
AWS_ACCESS_KEY_ID={{ .imgproxy_aws_access_key_id }}
AWS_SECRET_ACCESS_KEY={{ .imgproxy_aws_secret_access_key }}
{{ end }}
IMGPROXY_BIND=:{{ env "NOMAD_PORT_imgproxyhttp" }}
IMGPROXY_MAX_SRC_RESOLUTION=30
IMGPROXY_USE_S3=true
IMGPROXY_TTL=31536000
AWS_REGION="eu-north-1"
IMGPROXY_BASE_URL="s3://dsekt-tiki"
EOF
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
