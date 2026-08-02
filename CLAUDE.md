# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository layout

Two independent halves; the project root itself is **not** a git repo.

- `terraform/` — the actual work: AWS infrastructure (VPC, EKS, ECR) for hosting the sample app.
- `voting-app/` — an unmodified clone of `dockersamples/example-voting-app` (its own git repo, remote `origin` points at the upstream GitHub project). Treat it as vendored reference material: the deployable artifact, not the thing being authored. Prefer expressing changes in `terraform/` (or new manifests) over editing files inside this clone.

## Terraform

All commands run from `terraform/`. Region is `eu-west-2`, AWS account `801497981564`.

```bash
terraform init          # required after adding/changing a module block
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
tflint                  # installed locally
trivy config .          # installed locally; the code carries #trivy:ignore comments
```

State lives in S3 (`eks-project-tfstate-801497981564`) with **native S3 locking** (`use_lockfile`), not DynamoDB — this is why `required_version >= 1.11.0`.

### Current state: the root module does not validate

[terraform/main.tf](terraform/main.tf) references `local.env.ecr_repository_name` but no `locals` block exists anywhere in the configuration. The three ECR module blocks are also half-finished — `vote-ecr` and `result-ecr` request the same repository name and `worker-ecr` passes `""`. Expect `terraform validate`/`plan` to fail until this is resolved; run `terraform init` first, since the ECR modules were added after the last init.

### Architecture notes worth knowing before editing

- **EKS Auto Mode.** [modules/eks/main.tf](terraform/modules/eks/main.tf) sets `bootstrap_self_managed_addons = false` and enables `compute_config`, `kubernetes_network_config.elastic_load_balancing`, and `storage_config.block_storage`. AWS manages nodes, the load balancer controller, and EBS CSI — do not add a managed node group, `aws-load-balancer-controller` Helm release, or EBS CSI addon alongside it. Cluster auth is `authentication_mode = "API"` (access entries, not `aws-auth`).
- **Load balancer placement is driven by subnet tags, not by `subnet_ids`.** The cluster is given private subnets only; public subnets carry `kubernetes.io/role/elb = 1` and private carry `kubernetes.io/role/internal-elb = 1`. Internet-facing LBs land in the public subnets via those tags. Adding public subnets to the cluster's `subnet_ids` would only risk nodes with public IPs.
- **Single NAT gateway** in the first public subnet, shared by all three AZs — cheap, and a deliberate single point of failure for egress.
- The `ecr` module is generic and reusable (lifecycle policy retaining `max_image_count` images, scan-on-push, AES256); one instance per application image.

## The voting app

Five services: Python/Flask `vote` → Redis (list `votes`) → .NET `worker` → Postgres → Node/Express+socket.io `result`. Service discovery is by hostname hard-coded in source (`redis`, `db`) with credentials `postgres:postgres` baked in — see [vote/app.py](voting-app/vote/app.py#L21), [worker/Program.cs](voting-app/worker/Program.cs#L19), [result/server.js](voting-app/result/server.js#L20). Any deployment must keep those Service names.

Local run (from `voting-app/`):

```bash
docker compose up                  # vote :8080, result :8081; vote hot-reloads, result runs under nodemon
docker compose --profile seed up -d  # optional: seed generated votes
docker compose -f result/docker-compose.test.yml up --build  # only test suite: casts one vote, asserts result page
```

Kubernetes manifests in `voting-app/k8s-specifications/` are the upstream ones: they pull prebuilt `dockersamples/examplevotingapp_*` images from Docker Hub and expose vote/result via **NodePort 31000/31001**. Those are unsuitable as-is for the EKS cluster here (nodes are in private subnets, and the ECR repos being provisioned are the intended image source) — expect to rewrite images and Service types rather than `kubectl apply` them unchanged.

```bash
aws eks update-kubeconfig --name example --region eu-west-2   # also exposed as a terraform output
```
