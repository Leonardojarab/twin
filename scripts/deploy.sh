#!/bin/bash
set -e

ENVIRONMENT=${1:-dev}          # dev | test | prod
PROJECT_NAME=${2:-twin}

echo "Deploying ${PROJECT_NAME} to ${ENVIRONMENT}..."

cd "$(dirname "$0")/.."        # project root

if [ "${APPLY_TERRAFORM:-false}" = "true" ]; then
  # 1. Build Lambda package (only needed for infra deploy)
  echo "Building Lambda package..."
  (cd backend && uv run deploy.py)

  # 2. Terraform init + apply
  cd terraform
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  AWS_REGION=${DEFAULT_AWS_REGION:-us-east-1}
  terraform init -input=false \
    -backend-config="bucket=twin-terraform-state-${AWS_ACCOUNT_ID}" \
    -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
    -backend-config="region=${AWS_REGION}" \
    -backend-config="dynamodb_table=twin-terraform-locks" \
    -backend-config="encrypt=true"

  if ! terraform workspace list | grep -q "$ENVIRONMENT"; then
    terraform workspace new "$ENVIRONMENT"
  else
    terraform workspace select "$ENVIRONMENT"
  fi

  if [ "$ENVIRONMENT" = "prod" ]; then
    terraform apply -var-file=prod.tfvars -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" -auto-approve
  else
    terraform apply -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" -auto-approve
  fi

  API_URL=$(terraform output -raw api_gateway_url)
  FRONTEND_BUCKET=$(terraform output -raw s3_frontend_bucket)
  CUSTOM_URL=$(terraform output -raw custom_domain_url 2>/dev/null || true)
  cd ..
else
  echo "Skipping Terraform (APPLY_TERRAFORM=false) — reading existing outputs..."
  cd terraform
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  AWS_REGION=${DEFAULT_AWS_REGION:-us-east-1}
  terraform init -input=false \
    -backend-config="bucket=twin-terraform-state-${AWS_ACCOUNT_ID}" \
    -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
    -backend-config="region=${AWS_REGION}" \
    -backend-config="dynamodb_table=twin-terraform-locks" \
    -backend-config="encrypt=true"
  terraform workspace select "$ENVIRONMENT" 2>/dev/null || true

  API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
  FRONTEND_BUCKET=$(terraform output -raw s3_frontend_bucket 2>/dev/null || echo "")
  CUSTOM_URL=$(terraform output -raw custom_domain_url 2>/dev/null || true)
  cd ..
fi

# 3. Build + deploy frontend (only if infra exists)
if [ -z "$FRONTEND_BUCKET" ]; then
  echo "No infrastructure found — skipping frontend deploy."
  echo "Run with APPLY_TERRAFORM=true to create infrastructure first."
  exit 0
fi

echo "Setting API URL for production..."
echo "NEXT_PUBLIC_API_URL=$API_URL" > frontend/.env.production

cd frontend
npm install
npm run build
aws s3 sync ./out "s3://$FRONTEND_BUCKET/" --delete
cd ..

# 4. Final messages
echo ""
echo "Deployment complete!"
echo "CloudFront URL : $(terraform -chdir=terraform output -raw cloudfront_url 2>/dev/null || echo 'N/A')"
[ -n "$CUSTOM_URL" ] && echo "Custom domain  : $CUSTOM_URL"
echo "API Gateway    : $API_URL"
