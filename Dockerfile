# Forked-build of etcd-io/etcd into a 4-arch openweft image
# (linux/amd64 + arm64 + riscv64 + loong64). Tracks upstream releases
# via the ETCD_VERSION build-arg ; bump = one ARG change + a `vX.Y.Z`
# git tag here.
#
# Build :
#   docker buildx build --platform=linux/amd64,linux/arm64,linux/riscv64,linux/loong64 \
#     --build-arg ETCD_VERSION=v3.6.0 \
#     -t ghcr.io/openweft/weft-etcd:v3.6.0 .

ARG ETCD_VERSION=v3.6.0
ARG GO_VERSION=1.23

FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-bookworm AS builder
ARG ETCD_VERSION TARGETOS TARGETARCH
WORKDIR /src
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates && rm -rf /var/lib/apt/lists/*
RUN git clone --depth=1 --branch=${ETCD_VERSION} https://github.com/etcd-io/etcd.git .
ENV CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH}
# etcd 3.6 is a multi-module repo : each tool ships its own go.mod.
# Build each separately so GOOS/GOARCH propagate consistently.
RUN cd server   && go build -trimpath -ldflags="-s -w" -o /out/etcd    .
RUN cd etcdctl  && go build -trimpath -ldflags="-s -w" -o /out/etcdctl .
RUN cd etcdutl  && go build -trimpath -ldflags="-s -w" -o /out/etcdutl .

FROM scratch
ARG ETCD_VERSION
LABEL org.opencontainers.image.title="weft-etcd" \
      org.opencontainers.image.description="openweft 4-arch build of etcd-io/etcd" \
      org.opencontainers.image.version="${ETCD_VERSION}" \
      org.opencontainers.image.source="https://github.com/openweft/weft-etcd" \
      org.opencontainers.image.url="https://github.com/openweft/weft-etcd" \
      org.opencontainers.image.licenses="Apache-2.0"
# distroless/static doesn't ship riscv64/loong64 manifests ; scratch
# works on every arch buildkit can produce. We bring CA certs +
# /etc/passwd (for "nobody") + tzdata across explicitly.
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /out/etcd    /usr/local/bin/etcd
COPY --from=builder /out/etcdctl /usr/local/bin/etcdctl
COPY --from=builder /out/etcdutl /usr/local/bin/etcdutl
EXPOSE 2379 2380
ENTRYPOINT ["/usr/local/bin/etcd"]
