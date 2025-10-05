# Cloud Run production image for reporting
# Stage 1: Builder
FROM node:20-slim AS builder
RUN corepack enable

WORKDIR /app

# Copy workspace manifests
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY tsconfig.base.json tsconfig.service.json ./

# Copy source code
COPY packages ./packages
COPY services/reporting ./services/reporting

# Install ALL dependencies (including devDependencies for building)
RUN pnpm -w install --include-workspace-root --filter @app/reporting...

# Build all needed packages
RUN pnpm --filter @app/common build && pnpm --filter @app/reporting build

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
COPY --from=builder /app/services/reporting/dist ./services/reporting/dist
COPY --from=builder /app/services/reporting/package.json ./services/reporting/

# Install only production dependencies
RUN pnpm -w install --frozen-lockfile --filter @app/reporting... --prod

# Final runtime
WORKDIR /app/services/reporting
CMD ["node","dist/index.js"]
