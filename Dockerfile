# syntax=docker/dockerfile:1
FROM node:20-alpine AS deps
RUN apk add --no-cache libc6-compat python3 make g++ && corepack enable
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

FROM node:20-alpine AS builder
RUN corepack enable
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# NEXT_PUBLIC_* values are inlined into the client bundle at build time
ARG NEXT_PUBLIC_APP_URL=https://ai-video-generator-template-52b7a1.anysites.app
ARG NEXT_PUBLIC_BILLING_PROVIDER=creem
ENV NEXT_PUBLIC_APP_URL=$NEXT_PUBLIC_APP_URL \
    NEXT_PUBLIC_BILLING_PROVIDER=$NEXT_PUBLIC_BILLING_PROVIDER
# Env vars are validated at runtime, not at build time; the build container has a 1.5GB memory cap
ENV SKIP_ENV_VALIDATION=1 \
    NEXT_TELEMETRY_DISABLED=1 \
    NODE_OPTIONS=--max-old-space-size=1280
RUN pnpm build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
EXPOSE 3000
CMD ["node", "server.js"]
