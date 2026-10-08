# Build hello-api. ARCH=arm64 matches a Multipass VM on Apple Silicon;
# most VPSs are amd64: make build-linux ARCH=amd64
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
ARCH    ?= arm64
LDFLAGS := -s -w -X main.version=$(VERSION)

.PHONY: run build build-linux clean

run:
	go run .

build:
	go build -ldflags "$(LDFLAGS)" -o bin/hello-api .

build-linux:
	GOOS=linux GOARCH=$(ARCH) CGO_ENABLED=0 go build -ldflags "$(LDFLAGS)" -o bin/hello-api-linux-$(ARCH) .

clean:
	rm -rf bin
