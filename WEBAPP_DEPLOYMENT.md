# Webapp Deployment Guide

## Overview
The webapp is now a static Vite application served through S3 and CloudFront instead of running on ECS.

## Architecture Changes

### Before
```
Internet → Cloudflare → ALB → ECS (EC2) → Webapp Container
```

### After
```
Internet → Cloudflare → CloudFront → S3 (Static Files)
                      ↓
                     ALB → ECS (EC2) → API Container (/api/*)
```

## Benefits
- **Cost Reduction**: No EC2 instances needed for webapp
- **Better Performance**: CloudFront CDN caching
- **Improved Scalability**: S3 scales automatically
- **No Public IPs Needed**: Static files served from S3

## Environment Variables

The following environment variables need to be set during the **build process** (not runtime):

```bash
VITE_GOOGLE_CLIENT_ID=264792512466-81b98c4ctp11qj177mgmj817o23a12bn.apps.googleusercontent.com
VITE_GOOGLE_REDIRECT_URL=https://protoapp.xyz/api/auth/google/callback
VITE_API_URL=https://protoapp.xyz
VITE_STRIPE_PUBLISHABLE_KEY=pk_live_51PxCuHP3M2g0n0x3rpcflZx5JgmeMo7Le4eQFEj2coL6EwODaZ4L0YsfUGm32hXjzMruRZtmQXqUlvHcz2ZsVCwZ00O8C2Is5h
```

These values are embedded into the static files during build time via Vite's environment variable system.

## Build and Deployment Process

### 1. Build the Vite App
```bash
cd webapp
npm install
npm run build
```

### 2. Upload to S3
After running `terraform apply`, use the S3 bucket name from outputs:

```bash
# Get the bucket name
terraform output webapp_s3_bucket

# Upload the built files
aws s3 sync ./webapp/dist s3://$(terraform output -raw webapp_s3_bucket)/ --delete
```

### 3. Invalidate CloudFront Cache
After uploading new files, invalidate the CloudFront cache:

```bash
# Get the distribution ID
terraform output cloudfront_distribution_id

# Create invalidation
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw cloudfront_distribution_id) \
  --paths "/*"
```

## CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: Deploy Webapp

on:
  push:
    branches: [main]
    paths:
      - 'webapp/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Build
        working-directory: ./webapp
        env:
          VITE_GOOGLE_CLIENT_ID: ${{ secrets.VITE_GOOGLE_CLIENT_ID }}
          VITE_GOOGLE_REDIRECT_URI: ${{ secrets.VITE_GOOGLE_REDIRECT_URI }}
          VITE_STRIPE_PUBLISHABLE_KEY: ${{ secrets.VITE_STRIPE_PUBLISHABLE_KEY }}
        run: |
          npm install
          npm run build

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Deploy to S3
        run: |
          aws s3 sync ./webapp/dist s3://${{ secrets.S3_BUCKET_NAME }}/ --delete

      - name: Invalidate CloudFront
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }} \
            --paths "/*"
```

## Terraform Outputs

After applying the infrastructure changes, you'll have these outputs:

- `webapp_s3_bucket`: S3 bucket name for uploading static files
- `cloudfront_distribution_id`: CloudFront distribution ID for cache invalidation
- `cloudfront_domain_name`: CloudFront domain name
- `alb_dns_name`: ALB DNS (now only handles /api/* requests)

## DNS Configuration

The Cloudflare DNS records now point to CloudFront:
- `@` (root domain) → CloudFront distribution
- `www` → CloudFront distribution

CloudFront handles routing:
- All static assets (HTML, CSS, JS, images) → S3
- `/api/*` requests → ALB → ECS API service

## Monitoring

CloudWatch logs are configured at `/aws/cloudfront/webapp` with 14-day retention.

## Troubleshooting

### 404 Errors
The CloudFront distribution is configured to handle SPA routing by returning `index.html` for 404 errors. This allows client-side routing to work properly.

### Cache Issues
If you see stale content, create a CloudFront invalidation as shown above.

### API Not Working
Ensure the ALB security group allows inbound traffic from CloudFront. The CloudFront distribution forwards `/api/*` requests to the ALB with HTTPS.
