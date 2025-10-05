# Cloud Run production image for doctors
# Stage 1: Builder
FROM node:20-slim AS builder
RUN corepack enable

WORKDIR /app

# Copy workspace manifests
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY tsconfig.base.json tsconfig.service.json ./

# Copy source code
COPY packages ./packages
COPY services/doctors ./services/doctors

# Install ALL dependencies (including devDependencies for building)
RUN pnpm -w install --include-workspace-root --filter @app/doctors...

# Build all needed packages
RUN pnpm --filter @app/common build && pnpm --filter @app/doctors build

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
COPY --from=builder /app/services/doctors/dist ./services/doctors/dist
COPY --from=builder /app/services/doctors/package.json ./services/doctors/

# Install only production dependencies
RUN pnpm -w install --frozen-lockfile --filter @app/doctors... --prod

# Final runtime
WORKDIR /app/services/doctors
CMD ["node","dist/index.js"]
