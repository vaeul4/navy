# -----------------------------------------
# Stage 1: Builder
# -----------------------------------------
FROM golang:1.26-bookworm AS builder

# Set environment variables (Static build, decouple from C runtime dependencies)
ENV GO111MODULE=on
ENV CGO_ENABLED=0
ENV GOPATH=/go
ENV PATH=$GOPATH/bin:/usr/local/go/bin:$PATH

WORKDIR /root/naive

# Install xcaddy and build latest caddy with naive forwardproxy
RUN go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest \
    && /go/bin/xcaddy build \
       --with github.com/caddyserver/forwardproxy=github.com/klzgrad/forwardproxy@naive

# -----------------------------------------
# Stage 2: Minimal Runtime
# -----------------------------------------
# Align OS major version strictly with the Builder stage (Bookworm)
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libcap2-bin \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root/naive

COPY --from=builder /root/naive/caddy /root/naive/caddy

# Grant caddy the capability to bind privileged ports
RUN setcap cap_net_bind_service=+ep ./caddy

# Transfer ownership of the caddy binary to the unprivileged 'nobody' user
RUN chown nobody:nogroup ./caddy

# Critical security isolation: Enforce running as a non-root user
USER nobody

# Expose HTTP and HTTPS ports
EXPOSE 80 443

# Start caddy with config file
CMD ["./caddy", "run"]
