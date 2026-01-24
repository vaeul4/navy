FROM golang:1.25-rc-bullseye AS builder

# Set environment variables
ENV GO111MODULE=on
ENV CGO_ENABLED=1
ENV GOPATH=/go
ENV PATH=$GOPATH/bin:/usr/local/go/bin:$PATH

# Create working directory
WORKDIR /root/naive

# Install xcaddy and build caddy with naive forwardproxy
RUN go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest \
    && /go/bin/xcaddy build \
       --with github.com/caddyserver/forwardproxy=github.com/klzgrad/forwardproxy@naive \
       --with github.com/caddy-dns/cloudflare

# Second stage: minimal runtime image
FROM debian:bullseye-slim

# Install required tools
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libcap2-bin \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root/naive

# Copy caddy binary from builder stage
COPY --from=builder /root/naive/caddy /root/naive/caddy

# Allow binding to privileged ports (80/443) without root
RUN setcap cap_net_bind_service=+ep ./caddy

# Expose HTTP and HTTPS ports
EXPOSE 80 443

# Start caddy with config file
CMD ["./caddy", "run"]
