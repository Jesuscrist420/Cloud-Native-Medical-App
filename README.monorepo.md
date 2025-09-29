# Cloud-native Healthcare System (GCP)

This monorepo scaffolds 7 microservices, a shared package, and Terraform IaC for Google Cloud.

- Services: auth, appointments, payments, notifications, reporting, patients, doctors
- Event Bus: Google Pub/Sub (topics & subscriptions)
- Databases: Cloud SQL (PostgreSQL) with 1 DB per service
- Language: Node.js + TypeScript

## Local development

- Requires Node 20+ and pnpm 9+
- Each service runs on a different port, configured via env

## Structure

- packages/common: shared types & Pub/Sub helpers
- services/*: individual microservices
- infra/: Terraform for Pub/Sub and Cloud SQL

More docs will be added as we implement each component.
