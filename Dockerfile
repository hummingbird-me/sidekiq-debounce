FROM ruby:2.3-alpine
RUN apk add --no-cache git ruby-dev build-base
WORKDIR /app
ENV BUNDLE_PATH /app/.bundle
CMD sh
