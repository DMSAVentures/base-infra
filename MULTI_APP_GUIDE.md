# Multi-App Infrastructure Guide

This infrastructure supports running multiple web applications on a shared platform. Each app gets its own:
- **Domain** (managed via Cloudflare)
- **S3 + CloudFront** for static Vite webapp hosting
- **API container** running in ECS
- **Database** on the shared RDS instance
- **Secrets** stored in SSM Parameter Store

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Cloudflare DNS                          │
│  protoapp.xyz → CloudFront    app2.com → CloudFront            │
└─────────────────┬─────────────────────┬─────────────────────────┘
                  │                     │
         ┌────────▼────────┐   ┌────────▼────────┐
         │  CloudFront #1  │   │  CloudFront #2  │
         │  (protoapp.xyz) │   │    (app2.com)   │
         └────┬────────┬───┘   └────┬────────┬───┘
              │        │            │        │
        S3 Bucket   ALB:80     S3 Bucket   ALB:80
         (static)      │        (static)      │
                       │                      │
              ┌────────▼──────────────────────▼────────┐
              │    Application Load Balancer (ALB)     │
              │  Host-based routing: /api/* requests   │
              └────┬──────────────────────┬─────────────┘
                   │                      │
          ┌────────▼────────┐    ┌────────▼────────┐
          │  Target Group   │    │  Target Group   │
          │  (port 8080)    │    │  (port 8081)    │
          └────────┬────────┘    └────────┬────────┘
                   │                      │
      ┌────────────▼──────────────────────▼────────────┐
      │         ECS Service (Single Task)              │
      │  ┌──────────────────┐  ┌──────────────────┐   │
      │  │ protoapp-api     │  │ app2-api         │   │
      │  │ (port 8080)      │  │ (port 8081)      │   │
      │  └────────┬─────────┘  └────────┬─────────┘   │
      └───────────┼─────────────────────┼──────────────┘
                  │                     │
      ┌───────────▼─────────────────────▼──────────────┐
      │          RDS PostgreSQL Instance               │
      │  ┌────────────┐         ┌────────────┐        │
      │  │ protoapp_db│         │  app2_db   │        │
      │  └────────────┘         └────────────┘        │
      └───────────────────────────────────────────────┘
```

## Request Flow & Routing (Zero Misdirection)

### Static Assets (Webapp)
1. User → `https://protoapp.xyz/dashboard`
2. CloudFlare DNS → CloudFront Distribution
3. CloudFront → S3 Bucket (serves Vite build)
4. SPA routing via CloudFront Function (rewrites to /index.html)

### API Requests (Critical Routing)
1. User → `https://protoapp.xyz/api/users`
2. CloudFlare DNS → CloudFront Distribution
3. CloudFront → ALB (forwards /api/* requests)
4. **ALB Listener Rule** (THIS PREVENTS MISDIRECTION):
   - **Condition 1**: Host header = `protoapp.xyz` OR `www.protoapp.xyz`
   - **Condition 2**: Path = `/api/*`
   - **Action**: Forward to protoapp target group (port 8080)
5. Target Group → ECS Container `protoapp-api:8080`
6. Container connects to database `protoapp_db`

**Why this prevents misdirection:**
- If request has wrong host header, ALB returns 404 (no rule match)
- Each app ONLY receives requests for its own domain
- No cross-app API contamination possible

## Adding a New App

### Step 1: Add App Configuration

Edit `apps.tf` and add a new entry to `locals.apps_config`:

```hcl
locals {
  apps_config = {
    protoapp = {
      # ... existing config ...
    }

    # NEW APP
    mynewapp = {
      domain         = "mynewapp.com"      # Your domain (must be in Cloudflare)
      api_port       = 8081                # Unique port (increment from last app)
      api_image_repo = "mynewapp-server"   # ECR repository name
      database_name  = "mynewapp_db"       # Database name
      cpu            = 256                 # Container CPU units
      memory         = 256                 # Container memory (MB)

      # App-specific secrets (add your secrets to variables.tf first)
      env_secrets = {
        STRIPE_KEY = var.mynewapp_stripe_key
        # ... other secrets ...
      }
    }
  }
}
```

**Important:**
- Use a **unique port** for each app (8080, 8081, 8082, etc.)
- Domain must be managed by Cloudflare (same zone or different)
- ECR repository must exist before deployment

### Step 2: Add Secrets to variables.tf

If your app needs custom secrets, add them:

```hcl
variable "mynewapp_stripe_key" {
  description = "Stripe key for mynewapp"
  type        = string
  sensitive   = true
  default     = ""
}
```

### Step 3: Create ECR Repository

```bash
aws ecr create-repository --repository-name mynewapp-server --region us-east-1
```

### Step 4: Deploy

```bash
terraform plan
terraform apply
```

Terraform will automatically:
- ✅ Create database credentials in SSM
- ✅ Create S3 bucket for webapp
- ✅ Create CloudFront distribution
- ✅ Create ACM certificate
- ✅ Create Cloudflare DNS records
- ✅ Create ALB target group
- ✅ Add container to ECS task definition
- ✅ Configure ALB listener rule with host-based routing

### Step 5: Deploy Your Code

**API:**
```bash
# Build and push Docker image
docker build -t mynewapp-server .
docker tag mynewapp-server:latest <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/mynewapp-server:latest
docker push <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/mynewapp-server:latest

# ECS will automatically pull latest image on next deployment
```

**Webapp:**
```bash
# Build Vite app
npm run build

# Upload to S3
aws s3 sync dist/ s3://mynewapp.com-webapp --delete

# Invalidate CloudFront cache
aws cloudfront create-invalidation --distribution-id <DISTRIBUTION_ID> --paths "/*"
```

## Environment Variables

Each API container automatically receives:

### Database
- `DB_HOST` - RDS endpoint
- `DB_NAME` - App's database name
- `DB_USERNAME` - Generated username (from SSM)
- `DB_PASSWORD` - Generated password (from SSM)

### App Configuration
- `SERVER_PORT` - Container port (e.g., 8080)
- `GO_ENV` - Environment (production/staging)
- `GIN_MODE` - release
- `JWT_SECRET` - Auto-generated per app
- `WEBAPP_URI` - https://{domain}
- `GOOGLE_REDIRECT_URI` - https://{domain}/auth/callback

### Custom Secrets
All secrets from `env_secrets` in your app config are injected.

## Cloudflare Configuration

Each app automatically gets:
- ACM certificate validation records
- Root domain CNAME → CloudFront
- www subdomain CNAME → CloudFront
- SSL/TLS settings (strict mode, TLS 1.2+)

**Note:** All domains must be in the Cloudflare zone specified in `variables.tf`

## Database Management

### Create App Database

The database NAME is registered in SSM, but the actual database must be created manually:

```bash
# Connect to RDS
psql -h <RDS_ENDPOINT> -U <MASTER_USERNAME> -d postgres

# Create database and user
CREATE DATABASE mynewapp_db;
CREATE USER <USERNAME_FROM_SSM> WITH PASSWORD '<PASSWORD_FROM_SSM>';
GRANT ALL PRIVILEGES ON DATABASE mynewapp_db TO <USERNAME_FROM_SSM>;
```

Get credentials from SSM:
```bash
aws ssm get-parameter --name "/mynewapp/db/username" --with-decryption --query "Parameter.Value"
aws ssm get-parameter --name "/mynewapp/db/password" --with-decryption --query "Parameter.Value"
```

### Migrations

Run migrations from your API container:
```bash
# Get EC2 instance ID running ECS
aws ecs list-container-instances --cluster ecs-cluster

# Connect via SSM
aws ssm start-session --target <INSTANCE_ID>

# Find container
docker ps | grep mynewapp-api

# Run migrations
docker exec -it <CONTAINER_ID> ./migrate
```

## Monitoring & Logs

### CloudWatch Logs
Each app has its own log group:
```bash
aws logs tail /<app-name>/api --follow
```

### ECS Service
```bash
# Check service status
aws ecs describe-services --cluster ecs-cluster --services multi-app-api-service

# Check task health
aws ecs list-tasks --cluster ecs-cluster --service multi-app-api-service
aws ecs describe-tasks --cluster ecs-cluster --tasks <TASK_ARN>
```

### ALB Health Checks
Each target group runs health checks on `/health`:
```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn <TARGET_GROUP_ARN>
```

## Troubleshooting

### API Returns 404
1. Check ALB listener rules: `aws elbv2 describe-rules --listener-arn <LISTENER_ARN>`
2. Verify host header matches your domain
3. Check CloudFront is forwarding `Host` header (should be in module config)

### Container Not Starting
1. Check CloudWatch logs: `aws logs tail /<app-name>/api --follow`
2. Verify ECR image exists: `aws ecr describe-images --repository-name <repo-name>`
3. Check task definition: `aws ecs describe-task-definition --task-definition multi-app-api`

### Database Connection Fails
1. Verify security groups allow traffic from ECS to RDS
2. Check SSM parameters are correct
3. Ensure database and user were created in RDS

### CloudFront Not Serving Latest Files
```bash
# Invalidate cache
aws cloudfront create-invalidation --distribution-id <ID> --paths "/*"
```

## Security Best Practices

1. **Secrets**: Never commit `*.tfvars` files (already in .gitignore)
2. **SSM Parameters**: All secrets stored as SecureString type
3. **S3 Buckets**: Private, only accessible via CloudFront OAC
4. **RDS**: In private subnet, only accessible from ECS security group
5. **HTTPS**: Enforced via CloudFront and ALB, TLS 1.2+

## Cost Optimization

Shared resources across apps:
- ✅ Single ECS cluster
- ✅ Single EC2 instance (t3.micro)
- ✅ Single RDS instance (db.t3.micro)
- ✅ Single ALB

Per-app costs:
- S3 storage (pennies)
- CloudFront requests
- Data transfer

**Estimated cost for 5 apps:** ~$30-50/month

## File Structure

```
infra-setup/
├── apps.tf                   # Multi-app orchestration (MAIN CONFIG)
├── ecs-multi-app.tf          # ECS task definition with all containers
├── alb-multi-app.tf          # ALB host-based routing rules
├── ecs.tf                    # Shared ECS cluster
├── alb.tf                    # Shared ALB
├── vpc.tf                    # Shared VPC
├── db.tf                     # Shared RDS instance
├── modules/
│   ├── webapp/               # S3 + CloudFront module
│   ├── api-service/          # API container + target group module
│   └── app-database/         # Database credentials module
└── apps/
    ├── protoapp/
    │   ├── config.tf         # (deprecated - kept for reference)
    │   └── secrets.tfvars    # (deprecated)
    └── mynewapp/
        └── README.md         # App-specific notes
```

## Migration from Old Structure

The old single-app files have been renamed to `.old`:
- `api-service.tf.old`
- `webapp-service.tf.old`
- `s3-cloudfront.tf.old`
- `domain.tf.old`
- `secrets.tf.old`

These can be deleted after verifying the new structure works.

## Next Steps

1. ✅ Verify `terraform plan` shows expected changes
2. ✅ Run `terraform apply` to deploy
3. ✅ Create databases manually in RDS
4. ✅ Deploy API Docker images to ECR
5. ✅ Build and upload webapp static files to S3
6. ✅ Test each app individually
7. ✅ Monitor CloudWatch logs for errors

## Support

For issues:
1. Check CloudWatch logs first
2. Verify ALB routing rules
3. Check ECS task status
4. Review security groups
