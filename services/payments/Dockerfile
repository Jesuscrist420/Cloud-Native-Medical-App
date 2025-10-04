# Cloud Run production image for payments
FROM node:20-slim AS base
ENV NODE_ENV=production
RUN corepack enable

WORKDIR /app
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY tsconfig.base.json tsconfig.service.json ./
COPY packages ./packages
COPY services/payments ./services/payments

RUN pnpm -w install --frozen-lockfile --filter @app/payments...
RUN pnpm -w -r build --filter @app/payments...

WORKDIR /app/services/payments
CMD ["node","dist/index.js"]
