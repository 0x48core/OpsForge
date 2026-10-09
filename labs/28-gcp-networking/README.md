# Lab 28 — GCP networking: VPC, firewall, private access

- **Phase:** 9 — Google Cloud (GCP)
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** GCP (dev project)
- **Builds on:** Labs 13, 16, 27

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Build a private network: custom VPC, subnets, firewall rules, Cloud NAT, and SSH without public IPs.

## Done when

- [ ] Custom-mode VPC with regional subnets (asia-southeast1, Singapore) and explain why not the `default` network
- [ ] Firewall rules using network tags or service accounts; default deny ingress
- [ ] VMs without public IPs that still reach the internet via **Cloud NAT**
- [ ] SSH through **IAP TCP forwarding** (`gcloud compute ssh --tunnel-through-iap`): port 22 never open to the internet
- [ ] Cloud DNS: a public zone for your domain and a private zone inside the VPC

## Steps

## Code

## What broke

## Lessons learned

## References
