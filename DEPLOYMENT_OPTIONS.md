# Deployment Options

## Overview

The `deploy.sh` script supports multiple deployment modes to optimize your workflow and reduce deployment time.

## Usage

```bash
./deploy.sh [OPTIONS]
```

## Options

### Full Deployment (Default)

```bash
./deploy.sh
```

This performs a complete deployment:
1. ✅ Builds all 7 container images using Cloud Build
2. ✅ Pushes images to Artifact Registry
3. ✅ Deploys infrastructure with Terraform

**Time:** ~10-15 minutes
**Use when:** First-time deployment, code changes in services

---

### Infrastructure-Only Deployment

```bash
./deploy.sh --skip-build
```

This skips the container build phase and only deploys infrastructure:
1. ⏭️ Skips container builds (uses existing images)
2. ✅ Deploys/updates infrastructure with Terraform

**Time:** ~5-10 minutes
**Use when:**
- Only Terraform configuration changed
- Testing infrastructure updates
- Containers already built and pushed
- Updating environment variables or service configurations
- Adding/modifying databases, storage buckets, Pub/Sub topics

---

### Help

```bash
./deploy.sh --help
```

Displays available options and usage examples.

## Common Workflows

### Scenario 1: First Time Deployment
```bash
# Build everything and deploy infrastructure
./deploy.sh
```

### Scenario 2: Code Changes in Services
```bash
# Rebuild containers and redeploy
./deploy.sh
```

### Scenario 3: Terraform Changes Only
```bash
# Skip builds, just update infrastructure
./deploy.sh --skip-build
```

### Scenario 4: Update Environment Variables
```bash
# Skip builds, update Cloud Run services with new env vars
./deploy.sh --skip-build
```

### Scenario 5: Already Built Containers Manually
```bash
# Containers built separately, just deploy infrastructure
./deploy.sh --skip-build
```

## Performance Comparison

| Mode | Container Builds | Terraform Apply | Total Time | Use Case |
|------|-----------------|----------------|------------|----------|
| Full | ~7-10 min | ~5-10 min | ~12-20 min | Code changes |
| Skip Build | 0 min | ~5-10 min | ~5-10 min | Config changes |

## Exit Codes

- `0` - Success
- `1` - Error or user cancelled

## Examples

### Example 1: Quick infrastructure update
```bash
# You've updated Terraform to add a new Storage bucket
# No need to rebuild containers
./deploy.sh --skip-build
```

### Example 2: Update Cloud Run memory limits
```bash
# Modified main.tf to increase memory allocation
# Containers don't need rebuilding
./deploy.sh --skip-build
```

### Example 3: Full redeployment
```bash
# Fixed a bug in the auth service
# Need to rebuild and redeploy everything
./deploy.sh
```

## Tips

1. **Save Time**: Use `--skip-build` whenever possible to save 7-10 minutes
2. **Iterative Development**: Build containers once, iterate on infrastructure with `--skip-build`
3. **CI/CD**: Full deployments for production, skip builds for staging config updates
4. **Debugging**: Use `--skip-build` to quickly test infrastructure fixes

## Troubleshooting

### "Image not found" errors
If you get errors about missing container images when using `--skip-build`:
```bash
# Solution: Run a full deployment first
./deploy.sh
```

### Build failures
If containers fail to build:
```bash
# Check Cloud Build logs
gcloud builds list --limit=5

# View specific build
gcloud builds log <BUILD_ID>
```

## See Also

- [DEPLOYMENT.md](DEPLOYMENT.md) - Complete deployment guide
- [INFRASTRUCTURE.md](INFRASTRUCTURE.md) - Infrastructure details
- [README.md](README.md) - Project overview
