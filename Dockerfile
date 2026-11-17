# SouqAlGhanam 2.0 (سوق الغنم 2.0) — Production Container Image
# Multi-stage build for Vite SPA + Node/Express + WebSocket backend

FROM node:22-bookworm-slim AS deps
WORKDIR /app

# Install dependencies (including argon2 prebuilds & tsx runtime)
COPY package.json package-lock.json* ./
RUN npm ci

FROM node:22-bookworm-slim AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build Vite React production bundle into /app/dist
RUN npm run build

FROM node:22-bookworm-slim AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

# Create writable local fallback upload directory owned by non-root node user
RUN mkdir -p /app/data/uploads && chown -R node:node /app

COPY --from=builder --chown=node:node /app/package.json ./package.json
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/public ./public
COPY --from=builder --chown=node:node /app/server ./server
COPY --from=builder --chown=node:node /app/server.ts ./server.ts
COPY --from=builder --chown=node:node /app/drizzle ./drizzle
COPY --from=builder --chown=node:node /app/drizzle.config.ts ./drizzle.config.ts
COPY --from=builder --chown=node:node /app/scripts ./scripts
COPY --from=builder --chown=node:node /app/src/lib/listing-search.ts ./src/lib/listing-search.ts
COPY --from=builder --chown=node:node /app/src/assets/images ./src/assets/images
COPY --from=builder --chown=node:node /app/tsconfig.json ./tsconfig.json

USER node
EXPOSE 3000

# Check process liveness only so transient object-storage glitches do not force unnecessary container restarts.
# External monitors and load balancers should probe /api/v1/ready for DB + media readiness.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:' + (process.env.PORT || 3000) + '/api/v1/live').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"

CMD ["npm", "start"]
