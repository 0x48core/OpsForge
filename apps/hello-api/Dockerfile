# syntax=docker/dockerfile:1

# ---- Stage 1: build ----------------------------------------------------------
# Full Go toolchain (~300 MB), used only to compile. Not shipped.
# --platform=$BUILDPLATFORM: always run the compiler natively and let Go
# cross-compile for the target (fast), instead of emulating it with QEMU (slow).
FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS build
WORKDIR /src

# Download dependencies first: this layer is cached until go.mod/go.sum change,
# so editing code doesn't re-download modules.
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download

COPY . .
ARG VERSION=dev
ARG TARGETOS TARGETARCH
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -ldflags "-s -w -X main.version=${VERSION}" -o /out/hello-api .

# ---- Stage 2: run ------------------------------------------------------------
# Distroless: no shell, no package manager, just CA certs, tzdata, and a
# non-root user. Small and little to attack.
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/hello-api /hello-api

USER nonroot:nonroot
ENV HOST=0.0.0.0 PORT=8000
EXPOSE 8000

# --start-interval: check every second while starting, so a new container is
# marked healthy (and gets traffic from Traefik) quickly during a rolling deploy.
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --start-interval=1s --retries=3 \
    CMD ["/hello-api", "healthcheck"]

# Exec form: hello-api is PID 1 and receives SIGTERM directly from docker stop.
ENTRYPOINT ["/hello-api"]
