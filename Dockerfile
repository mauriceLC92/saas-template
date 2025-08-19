# Build frontend
FROM node:22-alpine AS builder-node
WORKDIR /app

COPY package*.json ./
RUN npm ci --frozen-lockfile

COPY . .

ARG DOMAIN_NAME
ARG PLAUSIBLE_API_HOST
RUN echo "VITE_DOMAIN=${DOMAIN_NAME}\nVITE_PLAUSIBLE_API_HOST=${PLAUSIBLE_API_HOST}" > .env

RUN npm run build:client

# Build backend
FROM golang:1.24-alpine AS builder-go
WORKDIR /app

COPY --from=builder-node /app/backend .
RUN go mod download
RUN CGO_ENABLED=0 go build -tags production -o longhabit

# Deploy binary
FROM alpine:latest AS runner
WORKDIR /app

# Create directory for PocketBase data
RUN mkdir -p /app/pb_data

COPY --from=builder-go /app/longhabit .
RUN chmod +x /app/longhabit

EXPOSE 8090

CMD ["/app/longhabit", "serve", "--http=0.0.0.0:8090"]