# Multi-App Infrastructure Platform

Production-ready AWS infrastructure for running multiple web applications on shared resources.

## What This Provides

- **Multi-app support**: Run unlimited apps on the same infrastructure
- **Zero misdirection routing**: Host-based ALB rules ensure API requests never cross apps
- **Automated provisioning**: Add an app in 5 minutes by editing one config file
- **Cost-efficient**: Share ECS cluster, ALB, RDS, and VPC across all apps
- **Cloudflare integration**: Automatic DNS and SSL certificate management

## Architecture

Each app gets:
- ✅ Separate domain (S3 + CloudFront for Vite webapp)
- ✅ Separate API container (ECS with dynamic port mapping)
- ✅ Separate database (on shared RDS instance)
- ✅ Separate secrets (SSM Parameter Store)
- ✅ Separate ALB routing rules (host-based to prevent misdirection)

Shared resources:
- ECS cluster (single EC2 instance)
- Application Load Balancer
- RDS PostgreSQL instance
- VPC and networking

## Quick Start

See [QUICK_START.md](./QUICK_START.md) for step-by-step instructions.

**TL;DR:**
1. Edit `apps.tf` to add your app config
2. Run `terraform apply`
3. Create database
4. Deploy API to ECR
5. Upload webapp to S3

## Full Documentation

- [MULTI_APP_GUIDE.md](./MULTI_APP_GUIDE.md) - Complete architecture and operations guide
- [QUICK_START.md](./QUICK_START.md) - Add a new app in 5 minutes
- [WEBAPP_DEPLOYMENT.md](./WEBAPP_DEPLOYMENT.md) - Webapp deployment guide (legacy)

## Current Apps

Run `terraform output apps_summary` to see all configured apps.

## File Structure

```
infra-setup/
├── apps.tf                   # MAIN CONFIG - Add apps here
├── ecs-multi-app.tf          # ECS task with all containers
├── alb-multi-app.tf          # ALB routing rules
├── modules/                  # Reusable modules
│   ├── webapp/
│   ├── api-service/
│   └── app-database/
├── ecs.tf                    # Shared ECS cluster
├── alb.tf                    # Shared ALB
├── vpc.tf                    # Shared VPC
└── db.tf                     # Shared RDS

*.old files are deprecated single-app configs (can be deleted)
```

## Prerequisites

- Terraform >= 1.2.0
- AWS CLI configured
- Cloudflare account with domain(s)
- ECR repository for each app's API

## Cost

**Shared infrastructure:** ~$25-35/month
- ECS: t3.micro EC2 instance
- RDS: db.t3.micro PostgreSQL
- ALB: Application Load Balancer
- VPC: Networking

**Per-app costs:** ~$2-5/month
- S3 storage (pennies)
- CloudFront requests
- Data transfer

**Total for 5 apps:** ~$35-50/month

## Security

- All secrets in SSM Parameter Store (SecureString)
- S3 buckets private (CloudFront OAC only)
- RDS in private subnet
- HTTPS enforced (TLS 1.2+)
- Host-based routing prevents API misdirection

## Support

For issues, check:
1. CloudWatch logs: `aws logs tail /<app-name>/api --follow`
2. ECS service: `aws ecs describe-services --cluster ecs-cluster --services multi-app-api-service`
3. ALB target health: `aws elbv2 describe-target-health --target-group-arn <arn>`
