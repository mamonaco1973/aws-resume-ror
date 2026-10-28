# Resume Scorer on AWS: Ruby on Rails on ECS Fargate with RDS, Redis and Bedrock

An AI **resume scoring** web app written in **Ruby on Rails 7.1** and run as
one container on **ECS Fargate** behind an **Application Load Balancer**.
Users paste resumes and submit job postings by URL, LinkedIn job ID or
pasted text; **Sidekiq**, running in the same container as Puma, has
**Claude Haiku on Amazon Bedrock** extract the job and score the resume from
0 to 100 with an overview, strengths and weaknesses. Data lives in **RDS
PostgreSQL**, the job queue in **ElastiCache Redis**, and files in **S3**
through ActiveStorage. Devise handles accounts and Pundit authorization.

[aws-resume-go](https://github.com/mamonaco1973/aws-resume-go) is a Go port
of this app on the same infrastructure.

| Piece | Where | Role |
|---|---|---|
| **VPC** | `10.0.0.0/23`, us-east-1 | two public and two private `/26` subnets across two AZs; a NAT gateway for the private subnets |
| **Application Load Balancer** | public subnets | HTTP on 80 to the task on 3000; with a custom domain, HTTPS on 443 (TLS 1.3 policy) and 80 redirects to it |
| **Route 53** + **ACM** | your hosted zone | only with a custom domain: a DNS-validated certificate and an alias record |
| **ECS Fargate service** | private subnets | one task, 1 vCPU and 2 GB; `startup.sh` waits for the database, runs migrations and seeds, starts Sidekiq in the background, then Puma; ECS Exec enabled; logs to `/ecs/resumescorer` for 7 days |
| **RDS PostgreSQL 16** | private subnets | `db.t3.micro`, 20 GB, not public |
| **ElastiCache Redis 7** | private subnets | `cache.t3.micro`, one node; the Sidekiq queue |
| **resumescorer-uploads-&lt;random&gt;** | S3 | private; ActiveStorage files such as job attachments |
| **resumescorer** | ECR | the app image, tagged with the build time |
| **Secrets Manager** | us-east-1 | `resumescorer_database_url`, `_redis_url`, `_secret_key_base`, `_bedrock_model_id`, `_smtp_user`, `_smtp_password`, injected into the task at start |

## Architecture

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="architecture-dark.svg">
  <img alt="A browser connects to an Application Load Balancer in the public subnets, on port 80 by its DNS name or, when a custom domain is set, on 443 through a Route 53 alias record with a DNS-validated ACM certificate. The load balancer forwards to one ECS Fargate task on port 3000 in the private subnets, running Rails under Puma with Sidekiq alongside. The task pulls its image from ECR, gets six settings from Secrets Manager at start, stores data in RDS PostgreSQL, queues scoring jobs in ElastiCache Redis, keeps ActiveStorage files in S3, and calls Claude Haiku on Amazon Bedrock through the NAT gateway." src="architecture-light.svg">
</picture>

Regenerate with `python3 make_diagram.py`.

- **`01-network/`**: the VPC and NAT gateway, RDS, ElastiCache, ECR, the
  uploads bucket and the secrets (database and Redis passwords are random).
- **`02-docker/resumescorer/`**: the Rails app and its `Dockerfile`.
- **`03-ecs/`**: the optional certificate and DNS records, the load
  balancer, the cluster, task definition and service, the security groups
  and the two roles.

The load balancer's security group allows 80 and 443 from anywhere; the
task's allows 3000 only from the load balancer; PostgreSQL and Redis allow
5432 and 6379 from the VPC. The task's execution role pulls the image and
reads the six secrets; its runtime role can use the uploads bucket, call
`bedrock:InvokeModel` and use ECS Exec.

## How a job is scored

1. Users register and sign in with Devise; it also handles password resets
   by email through the SMTP settings.
2. Submitting a job saves it as `pending` and enqueues `ScoringJob` in
   Sidekiq. LinkedIn job IDs become one job each.
3. The job fetches the posting or uses the pasted text, calls Bedrock once
   to extract the title, company and description, then again to score the
   resume, and saves the result as `scored`.
4. Each call's tokens are added to the user's total with an SQL increment.
   The default budget is 100,000 tokens per user, shown as a ring on the
   dashboard.

## Prerequisites

* [An AWS Account](https://aws.amazon.com/console/) with Bedrock access to
  Claude Haiku in `us-east-1`
* [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
* [Install Terraform](https://developer.hashicorp.com/terraform/install)
* [Install Docker](https://docs.docker.com/engine/install/)
* [Install jq](https://jqlang.github.io/jq/download/)

Optional settings, exported before `apply.sh`:

```bash
# HTTPS on your own hostname; the parent domain's Route 53 hosted zone
# must already exist. Without it, the app is served over HTTP on the
# load balancer's DNS name.
export AWS_RESUME_ROR_CUSTOM_DOMAIN="myjobs-ror.example.com"

# Password-reset email. Without these the SMTP secrets are empty and
# reset emails fail.
export SMTP_SERVER="smtp.improvmx.com"
export SMTP_PORT=587
export SMTP_USER="your-smtp-user"
export SMTP_PASSWORD="your-smtp-password"
```

If this is your first time following along, we recommend starting with this
video: [AWS + Terraform: Easy Setup](https://www.youtube.com/watch?v=9clW3VQLyxA).

## Deploy

```bash
git clone https://github.com/mamonaco1973/aws-resume-ror.git
cd aws-resume-ror
./apply.sh
```

`apply.sh` applies `01-network`, builds the image tagged with a timestamp
and pushes it to ECR, then applies `03-ecs` with that image and the custom
domain, if any. It ends by running `validate.sh`, which reads the app URL
from Terraform and polls `/users/sign_in` until it returns HTTP 200:

```
NOTE: Waiting for http://resumescorer-alb-<id>.us-east-1.elb.amazonaws.com/users/sign_in to return HTTP 200...
NOTE: Resume Scorer is healthy (HTTP 200).
NOTE: URL: http://resumescorer-alb-<id>.us-east-1.elb.amazonaws.com
```

## Try it

1. Open the URL and sign in as `demo@example.com` / `password123`. The seed
   data gives this user 2 resumes, 2 folders and 2 scored jobs. Or register
   at `/users/sign_up`.
2. Under **Resumes**, add a resume and paste its text (at least 50
   characters).
3. Under **Score a Job**, give a job URL, LinkedIn job IDs or the pasted
   description, pick a resume and optionally a folder, and submit. The job
   goes from `pending` to `scoring` to `scored`.
4. Open a scored job for the analysis and the extracted description, add
   notes, and upload attachments. Score badges are green at 75 and above,
   yellow at 50 and above, and red below 50; folders and a keyword search
   filter the dashboard.

## Teardown

```bash
./destroy.sh
```

## Notes

- **Lab only.** Anyone can register, and the seeded demo user has a known
  password. Without a custom domain the app, including sign-in, is plain
  HTTP.
- The old README said resumes are uploaded as PDFs; the app stores pasted
  text only (`content_text`), with no PDF parsing.
