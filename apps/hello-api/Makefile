# Build hello-api. ARCH=arm64 matches a Multipass VM on Apple Silicon;
# most VPSs are amd64: make build-linux ARCH=amd64
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
ARCH    ?= arm64
LDFLAGS := -s -w -X main.version=$(VERSION)

.PHONY: run test build build-linux docker-build clean

run:
	go run .

test:
	go vet ./...
	go test -race -count=1 ./...

build:
	go build -ldflags "$(LDFLAGS)" -o bin/hello-api .

build-linux:
	GOOS=linux GOARCH=$(ARCH) CGO_ENABLED=0 go build -ldflags "$(LDFLAGS)" -o bin/hello-api-linux-$(ARCH) .

docker-build:
	docker build --build-arg VERSION=$(VERSION) -t hello-api:$(VERSION) .

clean:
	rm -rf bin
