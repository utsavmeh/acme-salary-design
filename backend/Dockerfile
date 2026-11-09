# Production image for the Rails API (used by Railway). Development uses Dockerfile.dev.
# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.2.2
FROM ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development:test"

# Only what is needed to run: the PostgreSQL client library.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y libpq5 curl && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# ---- build stage: compilers live here only, so they stay out of the final image
FROM base AS build
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/cache "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

COPY . .
RUN bundle exec bootsnap precompile app/ lib/

# ---- final stage
FROM base
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run as an ordinary user, not root.
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log tmp
USER 1000:1000

EXPOSE 3000
# Create or update the tables, then start. PORT is provided by the host (Railway).
CMD ["bash", "-c", "bin/rails db:prepare && exec bin/rails server -b 0.0.0.0 -p ${PORT:-3000}"]
