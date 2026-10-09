# Lab 39 — Kubernetes internals: the control plane

- **Phase:** 10 — Kubernetes in depth
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** Compute Engine VMs (lab 29) with kubeadm
- **Builds on:** Labs 17, 18, 29, 33

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

See what K3s and GKE hide: build a cluster with kubeadm and follow a request through the control plane.

## Done when

- [ ] Install a 1 control plane + 2 worker cluster with **kubeadm** on GCE VMs
- [ ] Explain each control-plane component: kube-apiserver, etcd, scheduler, controller-manager; and on nodes: kubelet, container runtime (containerd), kube-proxy, CNI
- [ ] Follow `kubectl apply`: authentication → authorization → admission → etcd → controllers → scheduler → kubelet
- [ ] Read and write etcd directly with `etcdctl` (in a test cluster only)
- [ ] Explain the reconciliation loop with an example you break and watch heal

## Steps

## Code

## What broke

## Lessons learned

## References
