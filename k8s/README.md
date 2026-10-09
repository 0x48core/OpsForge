# k8s

Kubernetes for OpsForge (lab 12): a local K3s cluster in Docker, hello-api three ways, and GitOps with Argo CD.

| Path | What |
|---|---|
| [cluster/k3d.yaml](cluster/k3d.yaml) | K3s 1.35 cluster in Docker: 1 server + 2 agents, Ingress on `127.0.0.1:8081/8444` |
| [manifests/hello-api/](manifests/hello-api/) | Part 1: plain YAML (Deployment, StatefulSet, Services, Ingress, PDB) with Kustomize |
| [charts/hello-api/](charts/hello-api/) | Part 2: the same as a Helm chart; [values-k3d.yaml](charts/hello-api/values-k3d.yaml) = this cluster's settings |
| [argocd/hello-api.yaml](argocd/hello-api.yaml) | Part 3: Argo CD Application that syncs the chart from this repo |

## Quick start

```bash
k3d cluster create --config k8s/cluster/k3d.yaml
kubectl create namespace hello-api
kubectl -n hello-api create secret generic hello-api-db \
  --from-literal=POSTGRES_USER=hello \
  --from-literal=POSTGRES_PASSWORD="$(openssl rand -hex 16)" \
  --from-literal=POSTGRES_DB=hello

kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.4/manifests/install.yaml
kubectl apply -f k8s/argocd/hello-api.yaml

curl -H 'Host: api.k8s.opsforge.localhost' http://127.0.0.1:8081/ready
```

To deploy a new version: change `image.tag` in [values-k3d.yaml](charts/hello-api/values-k3d.yaml), commit, push. Argo CD does the rest.

The database password lives only in the cluster Secret, never in git.
