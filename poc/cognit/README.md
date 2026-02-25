# POC Cognit

Ansible playbooks to deploy OpenNebula 7.1 frontend + Cognit packages + KVM edge hosts + OneFlow service flavours from our private repos.

Edge hosts are provisioned via `oneprovision` using the **stock `onprem` driver** (no custom drivers).

## Architecture

```
deploy-frontend-and-node.yml          (full deploy, runs everything)
  ├── Bootstrap frontend with private APT repo
  ├── opennebula.deploy.pre           (one-deploy: prepare frontend)
  ├── opennebula.deploy.site          (one-deploy: install ONE frontend)
  ├── cognit-frontend.yml             (run once)
  │     ├── Cognit packages, services, marketplace, hooks
  │     ├── Monitoring fixes (kvm.rb patch, sqlite3 gem)
  │     ├── Ansible symlink fix for OneForm
  │     └── OneForm restart + driver registry (aws, scaleway)
  └── edge-cluster.yml                (run per flavour + provider)
        ├── Part A: oneprovision create onprem (edge cluster)
        │     └── Pre-create bridge on edge hosts (fixes eth0 enslavement)
        ├── Part B: Export marketplace app + deploy OneFlow service
        │     ├── Export marketplace app (Service <flavour>)
        │     ├── Wait for images to download
        │     ├── Instantiate OneFlow service
        │     └── Wait for all service VMs to be running
        └── Part C: Configure nginx ECF proxy + update cluster
              ├── Discover ECF Frontend VM IP from OneFlow service
              ├── Install nginx on edge host, proxy :1340 -> VM:1339
              └── Update cluster template (EDGE_CLUSTER_FRONTEND, FLAVOURS, PROVIDER)
```

## Prerequisites

- Ubuntu 24.04 VMs with root SSH, reachable from your laptop:
  - 1 frontend VM (4 GB RAM, 2 vCPUs, 20 GB disk)
  - 1+ edge host VMs (KVM nodes)
- **CPU model must be `host-passthrough`** on all VMs that act as KVM hosts (edge host VMs). Without it, the VMX flag is not exposed to the guest and nested KVM will fail (`/dev/kvm` missing, libvirt error: "does not support virt type 'kvm'").
- All VMs must reach `http://5.2.88.196/repo/` (private ONE+Cognit APT repo)
- Edge VMs must be SSH-reachable from the frontend

## Usage

### Option A: Full deploy (frontend + edge cluster in one shot)

```bash
ansible-playbook -i poc/cognit/inventory.yml \
  poc/cognit/deploy-frontend-and-node.yml \
  -e flavour=NatureFR -e provider=ProviderName
```

### Option B: Run playbooks independently

**Step 1** -- Set up the frontend (run once):

```bash
ansible-playbook -i poc/cognit/inventory.yml \
  poc/cognit/cognit-frontend.yml
```

**Step 2** -- Deploy edge cluster + OneFlow service for a flavour (repeatable):

```bash
ansible-playbook -i poc/cognit/inventory.yml \
  poc/cognit/edge-cluster.yml \
  -e flavour=NatureFR -e provider=ProviderName
```

Run this step multiple times with different flavours:

```bash
ansible-playbook -i poc/cognit/inventory.yml poc/cognit/edge-cluster.yml -e flavour=SmartCity -e provider=SomeProvider
ansible-playbook -i poc/cognit/inventory.yml poc/cognit/edge-cluster.yml -e flavour=EnergyTorch -e provider=SomeProvider
```

## Configuration

Edit `poc/cognit/inventory.yml`:
- `frontend.hosts.f1.ansible_host` = frontend VM IP
- `edge_host_ips` list = edge host VM IPs

## Testing offload

To verify offloading works, set `device-runtime-py/examples/cognit-template.yml`: use `api_endpoint: "http://<local_vm_frontend_ip>:1338"` and `credentials: "oneadmin:<one_pass>"`, where `<local_vm_frontend_ip>` is the frontend host (e.g. from `inventory.yml`) and `<one_pass>` is the `one_pass` value in `/one-deploy/poc/cognit/inventory.yml`.

## Available flavours

Must match marketplace app names (`onemarketapp list`):

| Flavour | Service App | FaaS Image App |
|---------|-------------|----------------|
| NatureFR | Service NatureFR | Cognit FaaS NatureFR |
| SmartCity | Service SmartCity | Cognit FaaS SmartCity |
| EnergyTorch | Service EnergyTorch | Cognit FaaS EnergyTorch |
| Energy | Service Energy | Cognit FaaS Energy |
| CyberSecurity | Service CyberSecurity | Cognit FaaS CyberSecurity |

## Automated fixes

The `cognit-frontend.yml` playbook applies these workarounds:

1. **KVM monitoring bug** (one-ee 7.1.80): patches `kvm.rb` where `info_each` discards `super`'s return value, causing `state.rb` to crash with `undefined method 'each' for nil`. Applied BEFORE provisioning so new hosts start monitored correctly.
2. **Ansible for OneForm**: pip installs `ansible-core` into `~oneadmin/.local/bin/` but OneForm can't find it. The playbook symlinks Ansible binaries to `/usr/local/bin/` and restarts OneForm.
3. **Stale Terraform**: removes `/usr/local/bin/terraform` if present (opennebula-form ships the correct version at `/usr/bin/terraform`).
4. **Private APT repo on edge hosts**: pre-writes the repo and patches the stock `onprem` driver's `ssh_cluster.j2` template so OneForm's Ansible doesn't overwrite it.
5. **sqlite3 gem on edge hosts**: installs the `sqlite3` Ruby gem required by monitoring probes, BEFORE oneprovision adds the hosts.
6. **onehost sync**: after provisioning, pushes patched monitoring remotes to all hosts.
