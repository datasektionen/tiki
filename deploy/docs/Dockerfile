ARG ELIXIR_VERSION=1.19.5
ARG OTP_VERSION=28.5
ARG DEBIAN_VERSION=trixie-20260505-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y && apt-get install -y build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

ENV MIX_ENV="docs"

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

COPY config/config.exs config/docs.exs config/dev.exs config/
RUN mix deps.compile

COPY priv/docs priv/docs
COPY assets/css/docs.css assets/css/docs.css
COPY docs docs

RUN mix compile
RUN mix docs_site.build

RUN mv /app/_docs_site/sws.toml /app/sws.toml

FROM ghcr.io/static-web-server/static-web-server:2
COPY --from=builder /app/_docs_site /public
COPY --from=builder /app/sws.toml /sws.toml
