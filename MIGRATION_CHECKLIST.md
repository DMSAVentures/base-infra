# Migration Checklist: Single App → Multi-App

This checklist helps you migrate from the old single-app setup to the new multi-app infrastructure.

## Pre-Migration

- [ ] **Backup current state**
  ```bash
  terraform state pull > terraform.tfstate.backup
  ```

- [ ] **Document current resources**
  ```bash
  terraform output > current-outputs.txt
  aws s3 ls | grep webapp > current-s3.txt
  aws ecr describe-repositories > current-ecr.txt
  ```

- [ ] **Verify protoapp config in apps.tf**
  - Domain: `protoapp.xyz`
  - API port: `8080`
  - Database: `protoapp_db`
  - All secrets mapped correctly

## Migration Steps

### 1. Remove Old Resources (Manual)

The old `.tf` files have been renamed to `.old`. You need to remove the old resources from state:

```bash
# List current resources
terraform state list

# Remove old single-app resources (DO NOT DELETE FROM AWS YET)
terraform state rm aws_ecs_service.ecs_service
terraform state rm aws_ecs_task_definition.task_definition
terraform state rm aws_cloudwatch_log_group.ecs_log_group
terraform state rm aws_s3_bucket.webapp_bucket
terraform state rm aws_cloudfront_distribution.webapp_distribution
terraform state rm aws_acm_certificate.ssl_cert
terraform state rm cloudflare_record.root_to_cloudfront
terraform state rm cloudflare_record.www_to_cloudfront
terraform state rm aws_alb_target_group.ecs_target
terraform state rm aws_lb_listener_rule.alb_listener_rule_api_http

# Remove old SSM parameters
terraform state rm aws_ssm_parameter.db_endpoint
terraform state rm aws_ssm_parameter.db_username
terraform state rm aws_ssm_parameter.db_password
terraform state rm aws_ssm_parameter.db_name
terraform state rm aws_ssm_parameter.jwt_secret
terraform state rm aws_ssm_parameter.google_client_id
terraform state rm aws_ssm_parameter.google_client_secret
terraform state rm aws_ssm_parameter.google_redirect_uri
terraform state rm aws_ssm_parameter.web_app_uri
terraform state rm aws_ssm_parameter.stripe_secret_key
terraform state rm aws_ssm_parameter.stripe_webhook_secret
terraform state rm aws_ssm_parameter.resend_api_key
terraform state rm aws_ssm_parameter.default_email_sender_address
terraform state rm aws_ssm_parameter.gemini_api_key
terraform state rm aws_ssm_parameter.openai_api_key
```

### 2. Plan New Infrastructure

```bash
terraform plan -out=migration.tfplan
```

**Review carefully:**
- [ ] New ECS service `multi-app-api-service` will be created
- [ ] New ECS task definition with protoapp container
- [ ] New ALB listener rule with host-based routing
- [ ] New S3 bucket (or import existing)
- [ ] New CloudFront distribution (or import existing)
- [ ] New SSM parameters under `/protoapp/` namespace

### 3. Import Existing Resources (Optional)

If you want to keep existing S3/CloudFront instead of recreating:

```bash
# Import S3 bucket
terraform import module.app_webapp[\"protoapp\"].aws_s3_bucket.webapp_bucket protoapp.xyz-webapp

# Import CloudFront distribution
terraform import module.app_webapp[\"protoapp\"].aws_cloudfront_distribution.webapp_distribution <DISTRIBUTION_ID>

# Import ACM certificate
terraform import aws_acm_certificate.app_cert[\"protoapp\"] <CERT_ARN>
```

### 4. Apply Migration

```bash
terraform apply migration.tfplan
```

**This will:**
- ✅ Create new multi-app ECS service
- ✅ Create new task definition with protoapp container
- ✅ Create new target group for protoapp
- ✅ Create new ALB listener rule (host-based)
- ✅ Create new S3/CloudFront (or update existing)
- ✅ Create new SSM parameters under `/protoapp/`

### 5. Verify Deployment

```bash
# Check ECS service is running
aws ecs describe-services --cluster ecs-cluster --services multi-app-api-service

# Check task is healthy
aws ecs list-tasks --cluster ecs-cluster --service multi-app-api-service
aws ecs describe-tasks --cluster ecs-cluster --tasks <TASK_ARN>

# Check target group health
aws elbv2 describe-target-health --target-group-arn $(terraform output -json apps_summary | jq -r '.protoapp.target_group_arn')

# Test API
curl https://protoapp.xyz/api/health

# Test webapp
curl https://protoapp.xyz
```

### 6. Update Database Credentials

The new system uses namespaced SSM parameters. Update your database:

```bash
# Get new credentials
NEW_USER=$(aws ssm get-parameter --name "/protoapp/db/username" --with-decryption --query "Parameter.Value" --output text)
NEW_PASS=$(aws ssm get-parameter --name "/protoapp/db/password" --with-decryption --query "Parameter.Value" --output text)

# Update database user (or keep using existing one)
# Option 1: Update SSM to use existing credentials
aws ssm put-parameter --name "/protoapp/db/username" --value "<OLD_USERNAME>" --overwrite
aws ssm put-parameter --name "/protoapp/db/password" --value "<OLD_PASSWORD>" --overwrite --type SecureString

# Option 2: Create new user with new credentials
psql -h <RDS_ENDPOINT> -U <MASTER_USER> -d postgres -c "CREATE USER $NEW_USER WITH PASSWORD '$NEW_PASS';"
psql -h <RDS_ENDPOINT> -U <MASTER_USER> -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE protoapp_db TO $NEW_USER;"
```

### 7. Clean Up Old Resources

**ONLY after verifying everything works:**

```bash
# Delete old ECS service (if still exists)
aws ecs delete-service --cluster ecs-cluster --service api_service --force

# Delete old task definitions (mark as inactive)
aws ecs deregister-task-definition --task-definition base-server:<revision>

# Delete old target group
aws elbv2 delete-target-group --target-group-arn <old-tg-arn>

# Delete old S3 bucket (if recreated)
aws s3 rb s3://protoapp.xyz-webapp --force

# Delete old CloudFront distribution (if recreated)
aws cloudfront delete-distribution --id <old-dist-id>

# Delete old SSM parameters (old namespace)
aws ssm delete-parameters --names \
  "/db/endpoint" \
  "/db/username" \
  "/db/password" \
  "/db/name" \
  "/jwt_secret" \
  # ... etc
```

### 8. Delete Old Terraform Files

```bash
rm *.tf.old
```

## Post-Migration Verification

- [ ] API responds correctly: `curl https://protoapp.xyz/api/health`
- [ ] Webapp loads: `curl https://protoapp.xyz`
- [ ] Database connections work
- [ ] Authentication works (OAuth, JWT)
- [ ] All integrations work (Stripe, email, etc.)
- [ ] CloudWatch logs are populated
- [ ] CloudFront cache works
- [ ] SSL certificate is valid

## Rollback Plan

If migration fails:

1. **Restore old state:**
   ```bash
   mv terraform.tfstate.backup terraform.tfstate
   terraform apply
   ```

2. **Revert file changes:**
   ```bash
   git checkout .
   mv api-service.tf.old api-service.tf
   mv webapp-service.tf.old webapp-service.tf
   mv s3-cloudfront.tf.old s3-cloudfront.tf
   mv domain.tf.old domain.tf
   mv secrets.tf.old secrets.tf
   rm apps.tf ecs-multi-app.tf alb-multi-app.tf
   ```

3. **Restart old ECS service:**
   ```bash
   aws ecs update-service --cluster ecs-cluster --service api_service --desired-count 1
   ```

## Timeline

Estimated migration time: **30-60 minutes**

- Planning & backup: 10 min
- State removal: 5 min
- Terraform apply: 10-15 min (CloudFront propagation)
- Verification: 10-15 min
- Cleanup: 10 min

## Downtime

**Zero downtime migration possible** if:
- You import existing S3/CloudFront resources
- You keep old ECS service running until new one is healthy
- You update DNS only after verification

**Minimal downtime option:**
- Let Terraform recreate resources (~5-10 min downtime)
- CloudFront propagation takes 15-30 min

## Support

If you encounter issues:

1. Check CloudWatch logs: `aws logs tail /protoapp/api --follow`
2. Check ECS task status: `aws ecs describe-tasks --cluster ecs-cluster --tasks <TASK_ARN>`
3. Check ALB listener rules: `aws elbv2 describe-rules --listener-arn <LISTENER_ARN>`
4. Verify security groups allow traffic
5. Check SSM parameters are correct
