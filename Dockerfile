ARG BUN_IMAGE=registry.cn-shanghai.aliyuncs.com/chongyejia/base-bun:1.4.4
ARG GOLANG_IMAGE=registry.cn-shanghai.aliyuncs.com/chongyejia/base-golang:1.26.10-alpine
ARG DEBIAN_IMAGE=registry.cn-shanghai.aliyuncs.com/chongyejia/base-debian:bookworm-slim

FROM ${BUN_IMAGE} AS builder

WORKDIR /build/web
COPY web/package.json web/bun.lock ./
RUN bun install --frozen-lockfile --registry=https://registry.npmmirror.com
COPY ./web ./
COPY ./VERSION /build/VERSION
RUN DISABLE_ESLINT_PLUGIN='true' VITE_REACT_APP_VERSION=$(cat /build/VERSION) bun run build

FROM ${GOLANG_IMAGE} AS builder2
ENV GO111MODULE=on CGO_ENABLED=0 GOWORK=off GOPROXY=https://goproxy.cn,direct

ARG TARGETOS
ARG TARGETARCH
ENV GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH:-amd64}
ENV GOEXPERIMENT=greenteagc

WORKDIR /build

ADD go.mod go.sum ./
# relaykit and tokenkit are local submodules referenced via replace; their
# go.mod files must be present for go mod download to resolve the main module graph.
ADD relaykit/go.mod ./relaykit/go.mod
ADD tokenkit/go.mod ./tokenkit/go.mod
RUN go mod download

COPY . .
COPY --from=builder /build/web/dist ./web/dist
RUN go build -pgo="$(go list -m -f '{{.Dir}}' github.com/MoeForge/moejs)/default.pgo" -ldflags "-s -w -X 'github.com/QuantumNous/new-api/common.Version=$(cat VERSION)'" -o new-api

FROM ${DEBIAN_IMAGE}

RUN find /etc/apt -type f \( -name 'sources.list' -o -name '*.sources' \) -exec sed -i -E \
        -e 's#https?://deb\.debian\.org/debian#http://mirrors.aliyun.com/debian#g' \
        -e 's#https?://security\.debian\.org/debian-security#http://mirrors.aliyun.com/debian-security#g' \
        {} + \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates tzdata libasan8 wget \
    && rm -rf /var/lib/apt/lists/* \
    && update-ca-certificates

COPY --from=builder2 /build/new-api /
COPY LICENSE NOTICE THIRD-PARTY-LICENSES.md /licenses/
EXPOSE 3000
WORKDIR /data
ENTRYPOINT ["/new-api"]
