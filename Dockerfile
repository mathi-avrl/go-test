FROM golang:1.26-alpine AS builder

# git is required by garble to patch the Go linker
RUN apk add --no-cache git

# Install garble
RUN go install mvdan.cc/garble@latest

WORKDIR /build

# Cache dependencies and verify them
COPY go.mod go.sum ./
RUN go mod download && go mod verify

COPY . .

# Check for vulnerabilities
RUN go run golang.org/x/vuln/cmd/govulncheck@v1.7.0 ./...

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \ 
    garble -tiny -literals -seed=random \
    build -trimpath -ldflags="-s -w" -o /build/learning-go ./main.go

# Use distroless static which contains CA certificates, timezone data, and a non-root user
FROM gcr.io/distroless/static-debian13:nonroot

WORKDIR /app

# Copy binary from build stage
COPY --from=builder --chown=nonroot:nonroot --chmod=700 /build/learning-go /app/learning-go

USER nonroot:nonroot

EXPOSE 8080

ENTRYPOINT ["/app/learning-go"]