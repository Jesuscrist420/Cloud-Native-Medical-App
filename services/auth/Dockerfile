# Cloud Run production image for auth
# Stage 1: Builder
FROM node:20-slim AS builder
RUN corepack enable

WORKDIR /app

# Copy workspace manifests
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY tsconfig.base.json tsconfig.service.json ./

# Copy source code
COPY packages ./packages
COPY services/auth ./services/auth

# Install ALL dependencies (including devDependencies for building)
RUN pnpm -w install --frozen-lockfile --filter @app/auth...

# Build all needed packages
RUN pnpm --filter @app/common build && pnpm --filter @app/auth build

# Stage 2: Production
FROM node:20-slim AS production
ENV NODE_ENV=production
RUN corepack enable

WORKDIR /app

# Copy workspace manifests
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./

# Copy built artifacts from builder
COPY --from=builder /app/packages/common/dist ./packages/common/dist
COPY --from=builder /app/packages/common/package.json ./packages/common/
COPY --from=builder /app/services/auth/dist ./services/auth/dist
COPY --from=builder /app/services/auth/package.json ./services/auth/

# Install only production dependencies
RUN pnpm -w install --frozen-lockfile --filter @app/auth... --prod

# Final runtime
WORKDIR /app/services/auth
CMD ["node","dist/index.js"]
