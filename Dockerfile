# DEVELOPMENT DOCKERFILE, NOT FOR PRODUCTION
# This Dockerfile is used to build a development image for the Phoenix application
# It only installs the necessary dependencies for development and testing
FROM elixir:slim

EXPOSE 4000

RUN apt-get update && \
    apt-get install -y postgresql-client inotify-tools git nodejs curl build-essential && \
    curl -L https://npmjs.org/install.sh | sh && \
    mix local.hex --force && \
    mix archive.install hex phx_new --force && \
    mix local.rebar --force

RUN apt-get install -y nginx

# Add stripe CLI
RUN curl -s https://packages.stripe.dev/api/security/keypair/stripe-cli-gpg/public | gpg --dearmor | tee /usr/share/keyrings/stripe.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/stripe.gpg] https://packages.stripe.dev/stripe-cli-debian-local stable main" | tee -a /etc/apt/sources.list.d/stripe.list

RUN apt-get update && apt-get install -y stripe

ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME
