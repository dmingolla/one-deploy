# POC Cognit

Ansible playbook to test Cognit packages locally: installs OpenNebula 7.1 frontend + Cognit package from our private repo on a single VM.

Tested with Ubuntu 24.04, 4 GB RAM, 2 vCPUs, 20 GB disk.

## Prerequisites

- A running Ubuntu 24.04 VM with root SSH, reachable from your laptop
- VPN access (`make sshuttle`) for the internal Jenkins ONE 7.1 repo
- VM must reach `http://5.2.88.196/repo/` (Cognit apt repo)

## Steps

**1. Start socat to forward Jenkins repo to the VM**

ONE 7.1 packages live on `jenkins.devel` (VPN only). The VM can't reach it directly, so forward via your laptop:

```bash
socat TCP-LISTEN:8081,bind=0.0.0.0,fork,reuseaddr TCP:jenkins.devel:80
```

Keep this running in a separate terminal.

**2. Set VM IP in inventory**

Edit `poc/cognit/inventory.yml`, set `ansible_host` under `frontend.hosts.f1` to your VM's IP.

**3. Check connectivity from the VM**

```bash
onevm ssh <VM_ID> --cmd "curl -sI http://172.20.0.1:8081/html/build/7.1.80-e7cfdfbd-bfb244f7-1016/ubuntu2404/repo/Ubuntu/24.04/dists/stable/Release"
onevm ssh <VM_ID> --cmd "curl -sI http://5.2.88.196/repo/"
```

Both should return HTTP 200. If the second fails, run on the OpenNebula host: `sudo ./poc/cognit/scripts/enable-vm-repo-access.sh`

**4. Run everything (OpenNebula + Cognit)**

```bash
pyenv shell ansible-6.0.0
ansible-playbook -i poc/cognit/inventory.yml poc/cognit/run-all.yml
```

This installs ONE 7.1 frontend from Jenkins, then adds the Cognit repo and installs `opennebula-cognit-frontend`.

**5. Check it worked**

```bash
onevm ssh <VM_ID> --cmd "dpkg -l opennebula-cognit-frontend"
onevm ssh <VM_ID> --cmd "systemctl status opennebula"
```

## Notes

- ONE 7.1 is not on the public repo; we use the internal Jenkins build via socat
- If reusing a VM from a failed run, clean stale repo files first: `onevm ssh <VM_ID> --cmd "rm -f /etc/apt/sources.list.d/opennebula.list"`
