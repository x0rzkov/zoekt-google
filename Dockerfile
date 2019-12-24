FROM golang:1.13-alpine AS builder

ARG TWINT_GENERATOR_VERSION

RUN apk add --no-cache make

COPY .  /go/src/github.com/google/zoekt
WORKDIR /go/src/github.com/google/zoekt

RUN cd /go/src/github.com/google/zoekt/cmd/zoekt-archive-index \
    && go build -v \
    && ls -lhS

RUN cd /go/src/github.com/google/zoekt/cmd/zoekt-git-clone \
    && go build -v \
    && ls -lhS

RUN cd /go/src/github.com/google/zoekt/cmd/zoekt-git-index \
    && go build -v \
    && ls -lhS

RUN cd /go/src/github.com/google/zoekt/cmd/zoekt-index \
    && go build -v \
    && ls -lhS

RUN cd /go/src/github.com/google/zoekt/cmd/zoekt-indexserver \
    && go build -v \
    && ls -lhS

RUN cd /go/src/github.com/google/zoekt/cmd/zoekt-mirror-bitbucket-server \
    && go build -v \
    && ls -lhS

RUN cd /go/src/github.com/google/zoekt/cmd/zoekt-mirror-gerrit \
    && go build -v \
    && ls -lhS

RUN cd /go/src/github.com/google/zoekt/cmd/zoekt-mirror-github \
    && go build -v \
    && ls -lhS

RUN cd /go/src/github.com/google/zoekt/cmd/zoekt-mirror-gitiles \
    && go build -v \
    && ls -lhS

RUN cd /go/src/github.com/google/zoekt/cmd/zoekt-mirror-gitlab \
    && go build -v \
    && ls -lhS

RUN cd /go/src/github.com/google/zoekt/cmd/zoekt-repo-index \
    && go build -v \
    && ls -lhS

RUN cd /go/src/github.com/google/zoekt/cmd/zoekt-sourcegraph-indexserver \
    && go build -v \
    && ls -lhS

RUN cd /go/src/github.com/google/zoekt/cmd/zoekt-test \
    && go build -v \
    && ls -lhS

RUN cd /go/src/github.com/google/zoekt/cmd/zoekt-webserver \
    && go build -v \
    && ls -lhS

RUN cd /go/src/github.com/google/zoekt/cmd/zoekt \
    && go build -v \
    && ls -lhS

FROM alpine:3.10 AS runtime

# Build argument
ARG VERSION
ARG BUILD
ARG NOW

# Install runtime dependencies & create runtime user
RUN apk --no-cache --no-progress add ca-certificates \
 && mkdir -p /opt \
 && adduser -D google -h /opt/google -s /bin/sh \
 && su google -c 'cd /opt/google; mkdir -p bin config data'

# Switch to user context
# USER google
WORKDIR /opt/google/data

# Copy gcse binary to /opt/gcse/bin
COPY --from=builder /go/src/github.com/google/zoekt/cmd/zoekt-archive-index /opt/google/bin/zoekt-archive-index
COPY --from=builder /go/src/github.com/google/zoekt/cmd/zoekt-git-clone /opt/google/bin/zoekt-git-clone
COPY --from=builder /go/src/github.com/google/zoekt/cmd/zoekt-git-index /opt/google/bin/zoekt-git-index
COPY --from=builder /go/src/github.com/google/zoekt/cmd/zoekt-index /opt/google/bin/zoekt-index
COPY --from=builder /go/src/github.com/google/zoekt/cmd/zoekt-indexserver /opt/google/bin/zoekt-indexserver
COPY --from=builder /go/src/github.com/google/zoekt/cmd/zoekt-mirror-bitbucket-server /opt/google/bin/zoekt-mirror-bitbucket-server
COPY --from=builder /go/src/github.com/google/zoekt/cmd/zoekt-mirror-gerrit /opt/google/bin/zoekt-mirror-gerrit
COPY --from=builder /go/src/github.com/google/zoekt/cmd/zoekt-mirror-github /opt/google/bin/zoekt-mirror-github
COPY --from=builder /go/src/github.com/google/zoekt/cmd/zoekt-mirror-gitiles /opt/google/bin/zoekt-mirror-gitiles
COPY --from=builder /go/src/github.com/google/zoekt/cmd/zoekt-mirror-gitlab /opt/google/bin/zoekt-mirror-gitlab
COPY --from=builder /go/src/github.com/google/zoekt/cmd/zoekt-repo-index /opt/google/bin/zoekt-repo-index
COPY --from=builder /go/src/github.com/google/zoekt/cmd/zoekt-sourcegraph-indexserver /opt/google/bin/zoekt-sourcegraph-indexserver
COPY --from=builder /go/src/github.com/google/zoekt/cmd/zoekt-test /opt/google/bin/zoekt-test
COPY --from=builder /go/src/github.com/google/zoekt/cmd/zoekt-webserver /opt/google/bin/zoekt-webserver
COPY --from=builder /go/src/github.com/google/zoekt/cmd/zoekt /opt/google/bin/zoekt

ENV PATH $PATH:/opt/google/bin

# Container metadata
LABEL name="zoekt" \
      version="$VERSION" \
      build="$BUILD" \
      architecture="x86_64" \
      build_date="$NOW" \
      vendor="google" \
      maintainer="x0rzkov <x0rzkov@protonmail.com>" \
      url="https://github.com/google/zoekt" \
      summary="Dockerized zoekt project" \
      description="Dockerized zoekt project" \
      vcs-type="git" \
      vcs-url="https://github.com/google/zoekt" \
      vcs-ref="$VERSION" \
      distribution-scope="public"

# Container configuration
EXPOSE 6070
VOLUME ["/opt/google/data"]

RUN chown -Rf google:google /opt/google/bin/* && echo $PATH && ls -lhS /opt/google/bin/
USER google

CMD ["zoekt-webserver"]




