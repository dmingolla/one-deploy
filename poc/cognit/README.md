# POC Cognit

Ansible playbook to test Cognit packages locally: installs OpenNebula 7.1 frontend + Cognit packages from our private repos on a single VM.

Tested with Ubuntu 24.04, 4 GB RAM, 2 vCPUs, 20 GB disk.

## Prerequisites

- A running Ubuntu 24.04 VM with root SSH, reachable from your laptop
- VM must reach `http://10.16.0.11/repo/` (internal ONE repo) and `http://5.2.88.196/repo/` (Cognit apt repo)

## Steps

**1. Set VM IP in inventory**

Edit `poc/cognit/inventory.yml`, set `ansible_host` under `frontend.hosts.f1` to your VM's IP.

**2. Check connectivity from the VM**

```bash
onevm ssh <VM_ID> --cmd "curl -sI http://10.16.0.11/repo/"
onevm ssh <VM_ID> --cmd "curl -sI http://5.2.88.196/repo/"
```

Both should return HTTP 200.

**3. Run everything (OpenNebula + Cognit)**

```bash
pyenv shell ansible-6.0.0
ansible-playbook -i poc/cognit/inventory.yml poc/cognit/run-all.yml
```

This configures the internal ONE repo, installs ONE 7.1 frontend, creates the Python venv, then adds the Cognit repo and installs `opennebula-cognit-frontend`, `opennebula-cognit-optimizer`, and `opennebula-cognit-devices-estimated-load`.

**4. Check it worked**

```bash
onevm ssh <VM_ID> --cmd "dpkg -l opennebula-cognit-frontend opennebula-cognit-optimizer opennebula-cognit-devices-estimated-load"
onevm ssh <VM_ID> --cmd "systemctl status opennebula opennebula-cognit-frontend"
```

## Notes

- The internal ONE repo URL is configured in `run-all.yml` (`one_internal_repo_url` var) -- change it if the repo moves
- one-deploy's built-in opennebula repo is disabled via `repos_enabled` in inventory (the internal repo uses a different dist/component layout)
- If reusing a VM from a failed run, clean stale repo files first: `onevm ssh <VM_ID> --cmd "rm -f /etc/apt/sources.list.d/opennebula.list"`
