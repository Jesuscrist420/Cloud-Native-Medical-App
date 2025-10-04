# Cloud Run production image for notifications
FROM node:20-slim AS base
ENV NODE_ENV=production
RUN corepack enable

WORKDIR /app
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY tsconfig.base.json tsconfig.service.json ./
COPY packages ./packages
COPY services/notifications ./services/notifications

RUN pnpm -w install --frozen-lockfile --filter @app/notifications...
RUN pnpm -w -r build --filter @app/notifications...

WORKDIR /app/services/notifications
CMD ["node","dist/index.js"]
