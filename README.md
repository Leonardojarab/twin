![AI Digital Twin](frontend/public/digitaltwin.png)

A production-ready AI chatbot platform that acts as a digital twin — an AI assistant that answers questions as if it were you. Built with Next.js, FastAPI, AWS Bedrock, and fully deployed on AWS serverless infrastructure via Terraform and GitHub Actions CI/CD.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Local Development](#local-development)
- [Configuration](#configuration)
- [Infrastructure](#infrastructure)
- [Deployment](#deployment)
- [CI/CD](#cicd)
- [API Reference](#api-reference)
- [Environments](#environments)

---

## Overview

The AI Digital Twin lets visitors interact with an AI version of you via a chat interface. The assistant uses your professional data (bio, resume, communication style) to answer questions about your background, experience, and skills. It is designed for personal branding, recruitment, or customer-facing use cases.

**Key features:**

- Conversational chat UI with session history
- Context-aware responses based on your personal data files
- Multi-environment support (dev / test / prod)
- Fully serverless — no servers to manage
- Secure CI/CD via GitHub Actions OIDC (no stored AWS credentials)

---

## Architecture

```
User Browser
    |
    | HTTPS
    v
CloudFront Distribution (CDN + cache)
    |
    |-- /             --> S3 Bucket (Next.js static frontend)
    |
    `-- /chat         --> API Gateway (HTTP)
                              |
                              v
                         Lambda Function (FastAPI / Python 3.12)
                              |
                              |-- Load conversation history  --> S3 (memory bucket)
                              |-- Call AWS Bedrock (Nova LLM)
                              |-- Save conversation history  --> S3 (memory bucket)
                              `-- Return response
```

**AWS services used:**

| Service | Role |
|---|---|
| CloudFront | CDN, HTTPS termination, SPA routing |
| S3 (frontend) | Static website hosting |
| S3 (memory) | Conversation history storage |
| API Gateway | HTTP API routing |
| Lambda | Serverless backend runtime |
| Bedrock | Managed LLM inference (Amazon Nova) |
| IAM | Role-based access control, OIDC for CI |
| ACM | TLS certificates (optional custom domain) |
| Route53 | DNS (optional custom domain) |
| DynamoDB | Terraform state lock |

---

## Tech Stack

### Frontend
- **Next.js 16** (React 19, App Router, static export)
- **TypeScript 5** (strict mode)
- **TailwindCSS 4**
- **Lucide React** (icons)

### Backend
- **Python 3.12**
- **FastAPI 0.129** + Uvicorn
- **Mangum** (ASGI adapter for Lambda)
- **Boto3** (AWS SDK)
- **AWS Bedrock Converse API** (Amazon Nova models)
- **PyPDF** (LinkedIn PDF ingestion)
- **uv** (fast Python package manager)

### Infrastructure
- **Terraform 1.0+** with AWS provider 6.0
- **S3 backend** with DynamoDB locking for Terraform state
- Multi-workspace (dev / test / prod)

### CI/CD
- **GitHub Actions**
- **AWS OIDC** authentication (no static credentials)

---

## Project Structure

```
twin/
├── backend/                    # Python FastAPI backend
│   ├── server.py               # FastAPI app (endpoints, chat logic)
│   ├── lambda_handler.py       # AWS Lambda entry point (Mangum adapter)
│   ├── context.py              # System prompt builder
│   ├── resources.py            # Personal data loader
│   ├── deploy.py               # Lambda deployment package builder
│   ├── data/
│   │   ├── facts.json          # Personal profile data
│   │   ├── summary.txt         # Professional summary
│   │   ├── style.txt           # Communication style guide
│   │   └── linkedin.pdf        # LinkedIn profile (optional)
│   ├── requirements.txt
│   └── pyproject.toml
│
├── frontend/                   # Next.js application
│   ├── app/
│   │   ├── page.tsx            # Home page
│   │   ├── layout.tsx          # Root layout
│   │   └── globals.css
│   ├── components/
│   │   └── twin.tsx            # Chat UI component
│   ├── public/                 # Static assets (avatar, favicon)
│   ├── package.json
│   ├── tsconfig.json
│   └── next.config.ts
│
├── terraform/                  # Infrastructure as Code
│   ├── main.tf                 # All AWS resources
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values (URLs, names)
│   ├── versions.tf             # Provider version constraints
│   ├── backend.tf              # S3 state backend
│   └── terraform.tfvars        # Default variable values
│
├── scripts/
│   ├── deploy.sh               # Main deployment script (Linux/Mac)
│   ├── deploy.ps1              # Deployment script (Windows)
│   ├── destroy.sh              # Infrastructure teardown (Linux/Mac)
│   └── destroy.ps1             # Infrastructure teardown (Windows)
│
├── .github/workflows/
│   ├── deploy.yml              # CI/CD deploy workflow
│   └── destroy.yml             # CI/CD destroy workflow
│
├── trust-policy.json           # AWS OIDC trust policy for GitHub Actions
├── .env.example                # Environment variable template
└── README.md
```

---

## Prerequisites

- [Node.js 20+](https://nodejs.org/) and npm
- [Python 3.12+](https://python.python.org/) and [uv](https://docs.astral.sh/uv/)
- [Terraform 1.0+](https://developer.hashicorp.com/terraform)
- [Docker](https://www.docker.com/) (for building the Lambda package)
- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials
- An AWS account with Bedrock model access enabled for your region

---

## Local Development

### 1. Clone and configure environment

```bash
git clone https://github.com/<your-org>/twin.git
cd twin
cp .env.example .env
# Edit .env with your AWS_ACCOUNT_ID and DEFAULT_AWS_REGION
```

### 2. Backend

```bash
cd backend
uv sync                        # Install dependencies
cp .env.example .env           # Configure local environment variables
uvicorn server:app --reload    # Start dev server on http://localhost:8000
```

Backend environment variables (`.env`):

```env
AWS_ACCOUNT_ID=123456789012
DEFAULT_AWS_REGION=eu-central-1
BEDROCK_MODEL_ID=eu.amazon.nova-2-lite-v1:0
CORS_ORIGINS=http://localhost:3000
USE_S3=false
MEMORY_DIR=../memory
```

### 3. Frontend

```bash
cd frontend
npm install
npm run dev                    # Start dev server on http://localhost:3000
```

The frontend calls `/chat` which proxies to the backend at `http://localhost:8000` in development.

---

## Configuration

### Personal data files

To customize the digital twin to represent a different person, edit the files in `backend/data/`:

| File | Purpose |
|---|---|
| `facts.json` | Structured profile: name, role, location, email, specialties, experience, education |
| `summary.txt` | Professional background paragraph |
| `style.txt` | Instructions for the AI's communication tone and style |
| `linkedin.pdf` | Full LinkedIn profile (optional — parsed automatically) |

### AI model

The default model is `eu.amazon.nova-2-lite-v1:0`. Other options:

| Model ID | Notes |
|---|---|
| `amazon.nova-micro-v1:0` | Fastest, lowest cost |
| `amazon.nova-lite-v1:0` | Balanced |
| `eu.amazon.nova-2-lite-v1:0` | Default (EU region) |
| `amazon.nova-pro-v1:0` | Most capable |

Set via `BEDROCK_MODEL_ID` environment variable or `terraform.tfvars`.

### Inference parameters

Configured in `backend/server.py`:

```python
inferenceConfig = {
    "maxTokens": 2000,
    "temperature": 0.7,
    "topP": 0.9,
}
```

---

## Infrastructure

All infrastructure is defined in `terraform/main.tf`. Key resources:

- **Lambda** — `{project}-{env}-api`, Python 3.12, x86_64, 60s timeout
- **API Gateway** — HTTP API with CORS enabled, routes: `GET /`, `POST /chat`, `GET /health`
- **CloudFront** — CDN with S3 origin, default TTL 3600s, 404 → index.html for SPA routing
- **S3 frontend** — Static website bucket for Next.js output
- **S3 memory** — Private bucket for per-session conversation history
- **IAM** — Lambda role with Bedrock and S3 access; OIDC role for GitHub Actions

### Terraform state backend

State is stored in S3 with DynamoDB locking. Configure in `terraform/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "{project}-terraform-state"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "{project}-terraform-locks"
    encrypt        = true
  }
}
```

### Custom domain (optional)

Set `domain_name` and `hosted_zone_id` in `terraform.tfvars` to enable Route53 + ACM HTTPS with a custom domain.

### API throttling

Configurable in `terraform.tfvars`:

```hcl
api_throttling_burst_limit = 10
api_throttling_rate_limit  = 5
```

---

## Deployment

### Manual deployment (Linux/Mac)

```bash
# Deploy to dev (default)
./scripts/deploy.sh dev twin

# Deploy to production
./scripts/deploy.sh prod twin
```

### Manual deployment (Windows)

```powershell
.\scripts\deploy.ps1 -Environment dev -ProjectName twin
```

### What the deploy script does

The script behavior depends on the `APPLY_TERRAFORM` environment variable:

**With `APPLY_TERRAFORM=false` (default):**
1. Reads existing Terraform outputs (API URL, S3 bucket)
2. If no infrastructure exists, exits with a message — nothing is created
3. If infrastructure exists, builds the Next.js frontend and uploads it to S3

**With `APPLY_TERRAFORM=true`:**
1. Builds the Lambda deployment package using Docker (AWS Lambda Python 3.12 image)
2. Initializes Terraform with the S3 backend
3. Creates or selects the named workspace (dev / test / prod)
4. Runs `terraform apply` — creates or updates all AWS infrastructure
5. Builds the Next.js frontend and uploads it to S3
6. Prints the CloudFront and API Gateway URLs

### Teardown

```bash
# Destroy a specific environment
./scripts/destroy.sh dev twin
```

The destroy script empties both S3 buckets before running `terraform destroy` to avoid non-empty bucket errors.

---

## CI/CD

Two GitHub Actions workflows are included.

### Deploy workflow (`.github/workflows/deploy.yml`)

**Trigger:** Manual only (`workflow_dispatch`) — never runs automatically on push.

**Inputs:**

| Input | Options | Default | Description |
|---|---|---|---|
| `environment` | dev / test / prod | `dev` | Target environment |
| `apply_terraform` | true / false | `false` | Whether to create/update AWS infrastructure |

**Authentication:** AWS OIDC — no long-lived credentials stored in GitHub secrets.

**Required secrets:**

| Secret | Description |
|---|---|
| `AWS_ACCOUNT_ID` | 12-digit AWS account number |
| `AWS_ROLE_ARN` | ARN of the GitHub Actions IAM role |
| `DEFAULT_AWS_REGION` | AWS region (e.g., `eu-central-1`) |

**Steps:**
1. Checkout code
2. Authenticate to AWS via OIDC
3. Set up Python 3.12 + uv
4. Set up Terraform
5. Set up Node.js 20
6. Run `scripts/deploy.sh` (with or without Terraform depending on input)
7. Retrieve Terraform outputs
8. Invalidate CloudFront cache
9. Print deployment summary

> To deploy infrastructure for the first time, run the workflow manually with `apply_terraform = true`.

### Destroy workflow (`.github/workflows/destroy.yml`)

**Trigger:** Manual only (safety measure)

**Inputs:** Environment name + confirmation string — you must type the environment name to confirm destruction.

### Setting up OIDC trust

Use the provided `trust-policy.json` to create the IAM OIDC provider and role in your AWS account. This allows GitHub Actions to assume an AWS role without static credentials.

---

## API Reference

Base URL: `https://<api-gateway-url>` (or `http://localhost:8000` locally)

### `GET /`

Health check. Returns API name and version.

### `GET /health`

Returns health status and active configuration.

### `POST /chat`

Send a message to the digital twin.

**Request body:**

```json
{
  "message": "What is your experience with machine learning?",
  "session_id": "optional-uuid-string"
}
```

**Response:**

```json
{
  "response": "I have 8 years of experience...",
  "session_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

If `session_id` is omitted, a new UUID is generated and returned. Subsequent requests with the same `session_id` continue the conversation.

### `GET /conversation/{session_id}`

Retrieve the full conversation history for a session.

---

## Environments

| Environment | Description |
|---|---|
| `dev` | Development — relaxed throttling, lower cost models |
| `test` | Staging — mirrors production configuration |
| `prod` | Production — uses `prod.tfvars`, full throttling |

Each environment gets its own Terraform workspace and isolated S3 buckets.
