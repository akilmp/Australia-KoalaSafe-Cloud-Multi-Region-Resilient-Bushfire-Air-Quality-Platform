# Australia - KoalaSafe Cloud – Multi‑Region Resilient Bushfire & Air‑Quality Platform

## Table of Contents

1. [Project Overview](#project-overview)
2. [High‑Level Architecture](#high-level-architecture)
3. [Tech Stack & AWS Services](#tech-stack--aws-services)
4. [Data Sources](#data-sources)
5. [Repository Layout](#repository-layout)
6. [Local Pre‑requisites](#local-pre-requisites)
7. [Infrastructure‑as‑Code (Terraform)](#infrastructure-as-code-terraform)
8. [Application Components](#application-components)

   * 8.1 [Ingestion Layer](#81-ingestion-layer)
   * 8.2 [Processing Layer](#82-processing-layer)
   * 8.3 [Storage & Persistence](#83-storage--persistence)
   * 8.4 [API Layer](#84-api-layer)
   * 8.5 [Frontend & Edge](#85-frontend--edge)
   * 8.6 [Alerting Pipeline](#86-alerting-pipeline)
9. [CI/CD Workflow](#cicd-workflow)
10. [Observability & SRE](#observability--sre)
11. [Disaster Recovery & Game‑Day Scenarios](#disaster-recovery--game-day-scenarios)
12. [Security & Compliance](#security--compliance)
13. [Cost Management](#cost-management)
14. [Demo Recording Guide](#demo-recording-guide)
15. [Troubleshooting & FAQ](#troubleshooting--faq)
16. [Stretch Goals](#stretch-goals)
17. [References & Further Reading](#references--further-reading)

---

## Project Overview

**KoalaSafe Cloud** is a multi‑region, serverless‑first AWS platform that ingests real‑time NSW bush‑fire incidents, NASA satellite hotspots, and NSW air‑quality sensor data. It processes, unifies, and geo‑indexes these feeds, serves a Mapbox‑based web dashboard, and sends user‑configured SMS / push alerts when an active fire perimeter intersects custom geo‑fences. The stack demonstrates every core competency expected of a 2025 Cloud Engineer:

| Competency                  | Demonstrated By                                                                                                     |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Infrastructure‑as‑Code      | Terraform 1.7 modules (core network, ingest, compute, edge) validated by tfsec & OPA                                |
| Multi‑region DR             | Active‑standby deployment in **ap‑southeast‑2** (Sydney) and **ap‑southeast‑4** (Melbourne) with Route 53 fail‑over |
| Serverless & Containers     | Lambda (Python 3.12) for ingestion; ECS Fargate (GeoJSON processing)                                                |
| CI/CD & GitOps              | GitHub Actions triggering lint ➜ unit tests ➜ Terraform Plan/Apply ➜ Blue/Green deploy                              |
| Observability               | AWS Distro for OpenTelemetry, Prometheus, Grafana Cloud dashboards, synthetic canaries                              |
| Security                    | IAM least privilege, KMS encryption, Secrets Manager rotation, CloudFront WAF                                       |
| FinOps                      | Savings Plans, S3 lifecycle rules, AWS Budgets + Slack alerts                                                       |
| Networking & Load Balancing | Dual‑AZ VPCs, ALB, Route 53 health checks, VPC endpoints                                                            |
| Automation & SRE            | Game‑day fail‑over script (`failure_sim.sh`) + Chaos test methodology                                               |

---

## High‑Level Architecture

```
       +----------------+               +----------------+
       | RFS Fires API  |               | NASA FIRMS API |
       +----------------+               +----------------+
                \                            /
                 \                          /
                  v  (Lambda Fetch)        v
             +-------------------------------------+
             |  Kinesis Firehose  (region‑local)    |
             +----------------+---------------------+
                              |
                              v  (Fargate Batch: GeoJSON union)
             +-------------------------------------+
             |       S3  Hot Bucket (GeoJSON)       |
             +-------------------------------------+
                              |
                 +------------+-------------+
                 | DynamoDB Global Table    |
                 | (User Geo‑fences)        |
                 +------------+-------------+
                              |
                              v
             +-------------------------------------+
             |  API Gateway  →  Lambda Authoriser  |
             +-------------------------------------+
                              |
                              v
             +-------------------------------------+
             |  CloudFront  +  S3 Static Frontend   |
             +-------------------------------------+
                              |
                              v
                 User Browser (React + Mapbox GL)

* Observability: ADOT ➜ Prometheus ➜ Grafana Cloud
* Fail‑over: Route 53 weighted record (health check ALB Sydney) ↔ Melbourne
```

A PNG + editable Draw\.io diagram sits at `docs/architecture.drawio`.

---

## Tech Stack & AWS Services

| Layer                | AWS Service                           | Notes                                  |
| -------------------- | ------------------------------------- | -------------------------------------- |
| Compute (Serverless) | Lambda                                | Ingest + light API layers              |
| Compute (Containers) | ECS Fargate                           | Batch GeoJSON processing; Spot capable |
| Streaming            | Kinesis Data Firehose                 | Simple, managed, low‑ops               |
| Storage              | S3 (hot), Glacier (archive)           | Cross‑region replication enabled       |
| Database             | DynamoDB Global Table                 | Low‑latency, multi‑Region              |
| API                  | Amazon API Gateway (REST)             | Cognito authoriser                     |
| Frontend             | S3 static + CloudFront                | WAF enabled                            |
| Messaging            | SNS                                   | SMS + Push bridge (Lambda to Expo)     |
| Identity             | Cognito User Pools + IAM              | User sign‑in & fine‑grained IAM roles  |
| Observability        | CloudWatch, Prometheus, Grafana Cloud | Centralised dashboards, alerts         |
| IaC                  | Terraform                             | `aws` + `null` + `random` providers    |
| CI/CD                | GitHub Actions + CodeDeploy           | Blue/Green ECS                         |

---

## Data Sources

| Feed                      | URL / Endpoint                                     | Update Freq | Auth       |
| ------------------------- | -------------------------------------------------- | ----------- | ---------- |
| NSW RFS Fires Near Me     | `https://www.fire.nsw.gov.au/feeds/.../fires.json` | 30 s pull   | Public     |
| NASA FIRMS (VIIRS, MODIS) | `https://firms.modaps.eosdis.nasa.gov/api/...`     | 5 min       | Key (free) |
| NSW Air Quality EPN       | `https://data.epa.nsw.gov.au/api/air_quality.csv`  | 10 min      | Public     |

Parser logic lives in `src/ingest_lambda/handlers.py`.

---

## Repository Layout

```
koalasafe-cloud/
├── terraform/
│   ├── core-network/              # VPC, subnets, SGs
│   ├── ingest-firehose/           # Lambda, Kinesis, IAM
│   ├── compute-fargate/           # ECS Cluster, Task, ALB
│   ├── data-storage/              # S3, DynamoDB, backup policies
│   └── edge-frontend/             # CloudFront, Route53, ACM
├── src/
│   ├── ingest_lambda/             # Python Lambda handler
│   └── geojson_processor/         # Dockerised Fargate app
├── frontend/                      # Vite + React + Mapbox
├── scripts/
│   └── failure_sim.sh             # Game‑day automation
├── .github/workflows/             # GHA pipelines
├── docs/
│   ├── architecture.drawio
│   ├── demo_script.md
│   └── cost_breakdown.xlsx
└── README.md
```

---

## Local Pre‑requisites

* **Docker** 24+
* **Terraform** 1.7 (`tfswitch 1.7.5` tested)
* **AWS CLI** v2 configured (`ap-southeast-2` profile)
* **Node.js** 20 (for frontend)
* **Python** 3.12 + Poetry (optional) for Lambda dev

---

## Infrastructure‑as‑Code (Terraform)

### Remote State & Workspaces

* `terraform/backend.tf` uses S3 bucket `koalasafe-tfstate` + DynamoDB lock table.
* Workspaces: `dev`, `prod`. Pushes from `main` branch apply to **prod** via GitHub Actions.

### Module Pattern

| Module            | Description                                  | Depends On       |
| ----------------- | -------------------------------------------- | ---------------- |
| `core-network`    | VPC (3 subnets/AZ, NAT GW), SGs              | none             |
| `ingest-firehose` | Lambda + Kinesis + IAM                       | network          |
| `compute-fargate` | ECS Cluster, Task, ALB                       | network, storage |
| `data-storage`    | S3 buckets, DynamoDB, replication, lifecycle | network          |
| `edge-frontend`   | ACM, CloudFront, Route 53, WAF               | storage          |

Each module has `variables.tf`, `outputs.tf`, `versions.tf`, and `main.tf`.

### `terraform apply`

```bash
cd terraform/core-network
terraform init -backend-config="profile=prod"
terraform workspace select prod || terraform workspace new prod
terraform apply -var-file=prod.tfvars
```

CI pipeline runs the same commands, but via `hashicorp/setup-terraform` action.

---

## Application Components

### 8.1 Ingestion Layer

* **Lambda (`src/ingest_lambda`)** pulls each feed on a 30 s EventBridge rule.
* Batches JSON/CSV rows → Firehose **“bushfire\_raw”** delivery stream with Lambda transformation for uniform schema.

### 8.2 Processing Layer (Fargate)

* Scheduled ECS task (`cron(0/5 * * * ? *)`) merges raw events into GeoJSON *fire\_perimeters.geojson* using Shapely + Fiona.
* Task definition has sidecar ADOT collector for metrics/traces.

### 8.3 Storage & Persistence

* `koalasafe-hot-${region}` S3 bucket (Standard‑IA after 7 days).
* Cross‑Region Replication replicates to opposite region bucket.\`
* DynamoDB table `geo_fences` (PK=user\_id, SK=fence\_id) with streams enabled for audit.

### 8.4 API Layer

| Method   | Path                | Auth             | Lambda           |
| -------- | ------------------- | ---------------- | ---------------- |
| `GET`    | `/geojson/latest`   | Public (API key) | `geojsonProxyFn` |
| `POST`   | `/alerts/subscribe` | Cognito          | `subscribeFn`    |
| `DELETE` | `/alerts/{id}`      | Cognito          | `unsubscribeFn`  |

### 8.5 Frontend & Edge

* **React** SPA built via Vite; deployed by `npm run deploy` → S3.
* CloudFront invalidation step in CI after upload.
* Mapbox GL JS; environment variables via `.env.production`.

### 8.6 Alerting Pipeline

```
DynamoDB Stream ➜ Lambda (rule_eval.py) ➜ EventBridge ➜ SNS "fire-alert" ➜
    ├── SMS (Australia numbers)
    └── Lambda (push_bridge.py) ➜ Expo Push API ➜ Mobile PWA
```

* SNS topic has KMS‑encrypted at rest; filter policies restrict region.

---

## CI/CD Workflow

GitHub Actions **`deploy-prod.yml`**:

```yaml
on:
  push:
    branches: [main]
permissions: write-all
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
      - run: pip install -r src/ingest_lambda/requirements.txt
      - run: pytest -q
      - uses: actions/setup-node@v4
      - run: npm ci --prefix frontend && npm run build --prefix frontend
  terraform:
    needs: test
    uses: hashicorp/setup-terraform@v3
    with:
      terraform_version: 1.7.5
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    steps:
      - run: terraform -chdir=terraform init
      - run: terraform -chdir=terraform plan -out=tfplan
      - run: terraform -chdir=terraform apply -auto-approve tfplan
  deploy-ecs:
    needs: terraform
    runs-on: ubuntu-latest
    steps:
      - uses: aws-actions/amazon-ecs-deploy-task-definition@v1
        with:
          task-definition: ecs_task.json
          service: ks-geojson-svc
          cluster: ks-ecs-cluster
          wait-for-service-stability: true
```

* **Secrets**: AWS creds, NPM\_TOKEN, MAPBOX\_TOKEN, EXPO\_TOKEN, NASA\_API\_KEY.

---

## Observability & SRE

| Metric / Log              | Tool             | Alert Threshold                        |
| ------------------------- | ---------------- | -------------------------------------- |
| `fires_processed_per_min` | Prometheus (ECS) | < 1 for 5 min                          |
| ALB 5xx (%)               | CloudWatch       | > 1 % over 1 min                       |
| Route 53 HealthCheck      | CloudWatch       | Unhealthy count ≥ 1 triggers fail‑over |
| Fargate CPU %             | CloudWatch       | > 80 % for 10 min → scale task to +1   |
| Budget `koalasafe-prod`   | AWS Budgets      | > \$30 month                           |

Grafana dashboards JSON exported to `docs/grafana/*.json`.

---

## Disaster Recovery & Game‑Day Scenarios

* **Fail‑over Mechanism**: Route 53 weighted records 80 % → Sydney, 20 % → Melbourne; health check on `/health` ALB path.
* **Game‑day Script** (`scripts/failure_sim.sh`):

  1. Terminates primary ALB.
  2. Monitors Route 53 `HealthCheckPercentage` until fail‑over occurs (< 60 s).
  3. Restores ALB; flips traffic back.
* **Chaos Plan**: Use SSM Automation to randomly stop ECS tasks during business hours once/week.

---

## Security & Compliance

| Control             | Implementation                                                                                        |
| ------------------- | ----------------------------------------------------------------------------------------------------- |
| IAM Least Privilege | Separate roles per Lambda; task role limited to S3 prefix, DynamoDB table.                            |
| KMS Encryption      | S3, SNS, DynamoDB, CloudFront logs.                                                                   |
| Secrets Management  | AWS Secrets Manager with 30‑day rotation (database & API keys).                                       |
| Network Isolation   | No public subnets except ALB; Lambda & Fargate in private subnets.                                    |
| WAF Rules           | Block common bot signatures, rate‑limit 1000 req/5 min/IP.                                            |
| Logging             | CloudFront, ALB, VPC Flow Logs → S3 partitioned by day.                                               |
| Policy‑as‑Code      | Conftest in CI blocks terraform plan if `aws_s3_bucket` lacks `server_side_encryption_configuration`. |

---

## Cost Management

| Resource             | Cost Driver             | Optimisation                                           |
| -------------------- | ----------------------- | ------------------------------------------------------ |
| **Lambda**           | Invocations             | 128 MB memory, 30 s avg → < AUD 3/mo                   |
| **Kinesis Firehose** | Ingest (500 KB/s)       | Buffer hint 1 MB, 60 s                                 |
| **Fargate**          | vCPU & RAM              | Spot capacity for batch; 1 × 0.5 vCPU/1 GB → AUD 15/mo |
| **S3**               | Storage (30 GB)         | Glacier after 30 days                                  |
| **Route 53**         | Health checks (2)       | AUD 1.60/mo                                            |
| **Grafana Cloud**    | Free tier (10 K series) | n/a                                                    |
| **Total (dev env)**  | ≈ **AUD 45 / month**    |                                                        |

Budgets alarm notifies Slack channel `#finops-koalasafe` at 80 % monthly threshold.

---

## Demo Recording Guide

**Tools**: OBS Studio 29, macOS/Win 1440p; Scene layout = webcam PiP bottom‑right.

| Segment           | Duration  | On‑Screen                                                              |
| ----------------- | --------- | ---------------------------------------------------------------------- |
| Intro             | 0:00‑0:30 | Selfie cam                                                             |
| Arch Diagram      | 0:30‑1:00 | `architecture.drawio` export                                           |
| Live Fail‑over    | 1:00‑2:00 | Browser 2‑up (Sydney vs Melbourne) + terminal running `failure_sim.sh` |
| Ingestion Metrics | 2:00‑3:00 | CloudWatch logs + Grafana metric panel                                 |
| Alert Trigger     | 3:00‑4:00 | Phone cam (receive SMS/push) + browser geo‑fence create modal          |
| CI/CD             | 4:00‑4:30 | GitHub Actions run, ECS deployment diff                                |
| Cost & Security   | 4:30‑5:30 | AWS Budgets graph + tfsec report                                       |
| Outro             | 5:30‑6:00 | Selfie cam                                                             |

Record at 60 FPS, export MP4 (YouTube preset), add captions for accessibility.

---

## Troubleshooting & FAQ

| Symptom                        | Cause                                    | Resolution                                                    |
| ------------------------------ | ---------------------------------------- | ------------------------------------------------------------- |
| `firehose delivery failed`     | Firehose transform Lambda timed‑out      | Increase timeout to 60 s; optimise JSON parsing               |
| API 5xx                        | GeoJSON S3 object missing                | Confirm Fargate task scheduled; check task logs               |
| Route 53 fail‑over never flips | Health check path wrong                  | `/health` returns 200 only if ECS target healthy              |
| Mapbox tiles blank             | Missing `MAPBOX_TOKEN` in CloudFront env | Set in `frontend/.env.production` and redeploy                |
| Budget alert not firing        | SNS->Slack subscription lost             | Re‑subscribe webhook; test with `aws budgets send-test-event` |

---

## Stretch Goals

* **Multi‑Cloud DR**: replicate S3 → GCS, use Cloud DNS; Fail‑over with StatusCake.
* **Policy‑as‑Code expansion**: AWS Config rules + Open Policy Agent for cost tags.
* **Predictive fire spread**: SageMaker inference endpoint feeding into Fargate post‑processor.
* **Edge Compute**: Run ingest at CloudFront Functions to reduce latency and egress.

---

## References & Further Reading

* NSW RFS API docs – [https://www.rfs.nsw.gov.au/resources/](https://www.rfs.nsw.gov.au/resources/)
* NASA FIRMS FAQ – [https://earthdata.nasa.gov/firms](https://earthdata.nasa.gov/firms)
* AWS Multi‑Region DR whitepaper 2025
* AWS Distro for OpenTelemetry – [https://aws.amazon.com/otel/](https://aws.amazon.com/otel/)
* Terraform Security Best Practices – HashiCorp 2024

---

*Last updated: 2 Aug 2025*
