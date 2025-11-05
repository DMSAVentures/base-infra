# ProtoApp Configuration

This directory contains the configuration for the ProtoApp application.

## Files

- `config.tf` - App configuration (domain, ports, resources)
- `secrets.tfvars` - Sensitive secrets (DO NOT COMMIT)

## Setup

1. Copy secrets from your current setup to `secrets.tfvars`
2. Run terraform with: `terraform apply -var-file="apps/protoapp/secrets.tfvars"`

## Environment Variables

The following environment variables are automatically injected into the API container:
- Database connection (DB_HOST, DB_USERNAME, DB_PASSWORD, DB_NAME)
- OAuth (GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REDIRECT_URI)
- Stripe (STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET)
- Email (RESEND_API_KEY, DEFAULT_EMAIL_SENDER_ADDRESS)
- AI APIs (GEMINI_API_KEY, OPENAI_API_KEY)
- App settings (SERVER_PORT, GO_ENV, GIN_MODE, WEBAPP_URI, JWT_SECRET)
