# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.1.3

# ---------------------------------------------------------------------------
# Build stage: compile native gem extensions with a full toolchain present.
# ---------------------------------------------------------------------------
FROM ruby:${RUBY_VERSION}-slim AS build

ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential libpq-dev git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /rails

# Gems are cached on their own layer so application edits do not re-resolve them.
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY . .

# ---------------------------------------------------------------------------
# Runtime stage: no compiler, no gem cache, no root. API-only, so there are no
# assets to precompile.
# ---------------------------------------------------------------------------
FROM ruby:${RUBY_VERSION}-slim AS runtime

ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test \
    RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=1 \
    PORT=3000

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y libpq5 curl tzdata && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd --system --gid 1000 rails && \
    useradd --system --uid 1000 --gid 1000 --create-home rails

WORKDIR /rails

COPY --from=build --chown=rails:rails /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=rails:rails /rails /rails

USER rails:rails

EXPOSE 3000

# /up is this app's own liveness endpoint: it checks the database connection and
# nothing else, so a Slack outage never marks the container unhealthy.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl --fail --silent "http://localhost:${PORT}/up" || exit 1

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
