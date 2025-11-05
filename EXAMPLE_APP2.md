# Example: Adding a Second App

This example shows how to add a second app called "myapp" to the infrastructure.

## Step 1: Update apps.tf

Open `apps.tf` and add the new app to `locals.apps_config`:

```hcl
locals {
  apps_config = {
    protoapp = {
      domain         = "protoapp.xyz"
      api_port       = 8080
      api_image_repo = "base-server"
      database_name  = "protoapp_db"
      cpu            = 256
      memory         = 256
      env_secrets = {
        GOOGLE_CLIENT_SECRET         = var.google_client_secret
        STRIPE_SECRET_KEY            = var.stripe_secret_key
        STRIPE_WEBHOOK_SECRET        = var.stripe_webhook_secret
        RESEND_API_KEY               = var.resend_api_key
        DEFAULT_EMAIL_SENDER_ADDRESS = var.default_email_sender_address
        GEMINI_API_KEY               = var.gemini_api_key
        OPENAI_API_KEY               = var.openai_api_key
      }
    }

    # NEW APP
    myapp = {
      domain         = "myapp.io"
      api_port       = 8081             # Different port!
      api_image_repo = "myapp-server"   # Your ECR repo
      database_name  = "myapp_db"
      cpu            = 256
      memory         = 256

      # App-specific secrets
      env_secrets = {
        STRIPE_SECRET_KEY = var.myapp_stripe_key
        SENDGRID_API_KEY  = var.myapp_sendgrid_key
      }
    }
  }
}
```

## Step 2: Add Secrets to variables.tf

Add variables for your app's secrets:

```hcl
variable "myapp_stripe_key" {
  description = "Stripe secret key for myapp"
  type        = string
  sensitive   = true
  default     = ""
}

variable "myapp_sendgrid_key" {
  description = "SendGrid API key for myapp"
  type        = string
  sensitive   = true
  default     = ""
}
```

## Step 3: Create ECR Repository

```bash
aws ecr create-repository --repository-name myapp-server --region us-east-1
```

## Step 4: Apply Infrastructure

```bash
# Plan to see what will be created
terraform plan

# Expected changes:
# + aws_acm_certificate.app_cert["myapp"]
# + cloudflare_record.app_root["myapp"]
# + cloudflare_record.app_www["myapp"]
# + module.app_database["myapp"]
# + module.app_api["myapp"]
# + module.app_webapp["myapp"]
# ~ aws_ecs_task_definition.multi_app_task (updated with new container)
# ~ aws_ecs_service.multi_app_service (updated with new load_balancer block)
# + aws_lb_listener_rule.app_api_routing["myapp"]

terraform apply
```

## Step 5: Get Infrastructure Outputs

```bash
terraform output apps_summary
```

You'll see:

```json
{
  "myapp": {
    "api_port": 8081,
    "cloudfront_domain": "d1234567890abc.cloudfront.net",
    "domain": "myapp.io",
    "s3_bucket": "myapp.io-webapp",
    "target_group_arn": "arn:aws:elasticloadbalancing:..."
  },
  "protoapp": { ... }
}
```

## Step 6: Create Database

```bash
# Get generated credentials
DB_USER=$(aws ssm get-parameter --name "/myapp/db/username" --with-decryption --query "Parameter.Value" --output text)
DB_PASS=$(aws ssm get-parameter --name "/myapp/db/password" --with-decryption --query "Parameter.Value" --output text)
DB_ENDPOINT=$(aws ssm get-parameter --name "/myapp/db/endpoint" --query "Parameter.Value" --output text)

# Connect to RDS (need master credentials)
psql -h $DB_ENDPOINT -U master_user -d postgres

# Create database and user
CREATE DATABASE myapp_db;
CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';
GRANT ALL PRIVILEGES ON DATABASE myapp_db TO $DB_USER;
\q
```

## Step 7: Build and Deploy API

```bash
# Get your AWS account ID
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO="$AWS_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/myapp-server"

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO

# Build API container
cd /path/to/myapp-api
docker build -t myapp-server .
docker tag myapp-server:latest $ECR_REPO:latest

# Push to ECR
docker push $ECR_REPO:latest

# Force ECS to deploy new task definition
aws ecs update-service \
  --cluster ecs-cluster \
  --service multi-app-api-service \
  --force-new-deployment
```

## Step 8: Build and Deploy Webapp

```bash
# Build Vite app
cd /path/to/myapp-webapp
npm install
npm run build

# Upload to S3
aws s3 sync dist/ s3://myapp.io-webapp --delete

# Get CloudFront distribution ID
DIST_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Aliases.Items[?contains(@, 'myapp.io')]].Id" \
  --output text)

# Invalidate cache
aws cloudfront create-invalidation \
  --distribution-id $DIST_ID \
  --paths "/*"
```

## Step 9: Verify Deployment

```bash
# Wait for ECS task to be running
aws ecs wait services-stable \
  --cluster ecs-cluster \
  --services multi-app-api-service

# Check container health
aws ecs describe-tasks \
  --cluster ecs-cluster \
  --tasks $(aws ecs list-tasks --cluster ecs-cluster --service multi-app-api-service --query 'taskArns[0]' --output text)

# Test API (wait for CloudFront propagation ~2-3 min)
curl https://myapp.io/api/health

# Test webapp
curl https://myapp.io

# Check logs
aws logs tail /myapp/api --follow
```

## Step 10: Configure Webapp Environment

Your webapp needs to be built with these environment variables:

```bash
# .env.production
VITE_API_URL=https://myapp.io/api
VITE_APP_NAME=MyApp
# ... other env vars
```

Rebuild and redeploy:

```bash
npm run build
aws s3 sync dist/ s3://myapp.io-webapp --delete
aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/*"
```

## Routing Verification

Your API will ONLY receive requests matching:
- **Host**: `myapp.io`, `www.myapp.io`, or `*.myapp.io`
- **Path**: `/api/*`

Test misdirection protection:

```bash
# This should work
curl -H "Host: myapp.io" https://myapp.io/api/health

# This should return 404 (wrong host)
curl -H "Host: protoapp.xyz" https://myapp.io/api/health

# This should return 404 (wrong path)
curl https://myapp.io/not-api/health
```

## Environment Variables in API Container

Your `myapp-server` container automatically receives:

```bash
# Database
DB_HOST=<rds-endpoint>
DB_NAME=myapp_db
DB_USERNAME=<auto-generated>
DB_PASSWORD=<auto-generated>

# App Config
SERVER_PORT=8081
GO_ENV=production
GIN_MODE=release
JWT_SECRET=<auto-generated-64-char>
WEBAPP_URI=https://myapp.io
GOOGLE_REDIRECT_URI=https://myapp.io/auth/callback

# Your Custom Secrets
STRIPE_SECRET_KEY=<from-variables.tf>
SENDGRID_API_KEY=<from-variables.tf>
```

## Shared Resources

Notice that both apps share:
- ✅ ECS cluster (same EC2 instance)
- ✅ ALB (same load balancer)
- ✅ RDS instance (different databases)
- ✅ VPC and networking

Check ECS task to see both containers running:

```bash
aws ecs describe-tasks \
  --cluster ecs-cluster \
  --tasks $(aws ecs list-tasks --cluster ecs-cluster --service multi-app-api-service --query 'taskArns[0]' --output text) \
  --query 'tasks[0].containers[*].[name,lastStatus,networkBindings[0].hostPort]' \
  --output table
```

Output:
```
--------------------------------
|      DescribeTasks           |
+---------------+---------+------+
|  protoapp-api | RUNNING | 32768|
|  myapp-api    | RUNNING | 32769|
+---------------+---------+------+
```

## Cost Impact

Adding this second app adds:
- S3 storage: ~$0.50/month (10GB)
- CloudFront requests: ~$1-2/month (1M requests)
- Data transfer: ~$1-2/month

**Total additional cost: ~$3-5/month**

No additional cost for:
- ECS (same instance)
- ALB (same load balancer)
- RDS (same instance, just another database)

## Troubleshooting

### API returns 502 Bad Gateway
- Container is likely not healthy
- Check logs: `aws logs tail /myapp/api --follow`
- Check container is listening on port 8081
- Verify environment variables are correct

### API returns 404
- CloudFront hasn't propagated yet (wait 2-3 min)
- Check ALB listener rules: `aws elbv2 describe-rules --listener-arn <ARN>`
- Verify host header is correct

### Database connection refused
- Check security groups allow ECS → RDS traffic
- Verify credentials in SSM are correct
- Test from ECS instance: `psql -h $DB_ENDPOINT -U $DB_USER -d myapp_db`

### Webapp shows old version
- Invalidate CloudFront: `aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/*"`
- Check S3 bucket has new files: `aws s3 ls s3://myapp.io-webapp/`

## Next Steps

Add a third app by repeating the process with:
- Domain: `app3.com`
- Port: `8082`
- ECR repo: `app3-server`

It just works! 🚀
