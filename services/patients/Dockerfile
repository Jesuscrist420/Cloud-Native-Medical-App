# Cloud Run production image for patients
FROM node:20-slim AS base
ENV NODE_ENV=production
RUN corepack enable

# Workdir at monorepo root in image
WORKDIR /app

# Copy workspace manifests first for better caching
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY tsconfig.base.json tsconfig.service.json ./

# Copy only needed workspaces
COPY packages ./packages
COPY services/patients ./services/patients

# Install only deps required for this service and its deps
RUN pnpm -w install --frozen-lockfile --filter @app/patients...

# Build all needed packages
RUN pnpm -w -r build --filter @app/patients...

# Final runtime
WORKDIR /app/services/patients
CMD ["node","dist/index.js"]
