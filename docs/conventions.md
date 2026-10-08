# Conventions

## Lab workflow

1. Copy `labs/_template/` to `labs/NN-short-name/` (or fill in the existing stub).
2. Work on a branch: `lab/NN-short-name`.
3. Write notes **while** doing the lab, not after — commands, errors, fixes.
4. Anything reusable goes into an infrastructure folder (see below); the lab README links to it.
5. A lab is ✅ only when every "Done when" item is checked. Update the roadmap in the root README.
6. Merge to `main`. Tag milestones if useful (`phase-1-done`).

## Where code lives

| Kind of code | Folder | Example |
|---|---|---|
| Sample app being deployed | `apps/<name>/` | `apps/demo-api/` |
| Docker Compose stack | `stacks/<name>/compose.yaml` | `stacks/traefik/` |
| Standalone shell script | `scripts/` | `scripts/backup.sh` |
| Server config | `ansible/` (roles per concern) | `ansible/roles/hardening/` |
| Cloud resources | `terraform/` | `terraform/envs/prod/` |
| Kubernetes | `k8s/` | `k8s/apps/demo-api/` |
| Pipelines | `.github/workflows/` | `deploy-demo-api.yml` |

Throwaway experiments may stay inside the lab folder under `labs/NN-*/scratch/`.

## Secrets — never commit them

- Real values go in `.env` files (git-ignored). Commit a `.env.example` with placeholder values next to it.
- Ansible secrets: `ansible-vault`. Terraform: `*.tfvars` (git-ignored) or environment variables.
- CI secrets: GitHub Actions secrets.
- Never write real IPs, SSH ports, or tokens into lab notes — use placeholders like `<VPS_IP>`, `<SSH_PORT>`.
- If something leaks: rotate it first, then clean the history.

## Naming

- Folders and files: `kebab-case`.
- Labs: two-digit number + short name: `07-cicd-pipeline`.
- Subdomains: one per service, `<service>.<domain>` (e.g. `git.example.com`).
- Branches: `lab/NN-name`, `fix/...`, `docs/...`.
- Commits: [Conventional Commits](https://www.conventionalcommits.org/) — `feat(ansible): add hardening role`, `docs(lab-01): add lessons learned`.

## Decisions

When choosing between tools (Traefik vs Nginx Proxy Manager, GitHub Actions vs Jenkins, Argo CD vs Flux…), write a short record in `docs/decisions/NNNN-title.md`: context, options, choice, why. See [0001](decisions/0001-record-decisions.md).
