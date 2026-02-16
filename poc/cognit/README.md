# POC Cognit

This Ansible playbook lets you test Cognit packages locally: it adds the project apt repo and installs the package on a frontend VM.

You need a VM already running locally (e.g. on your OpenNebula) that can reach the apt repo at http://5.2.88.196/repo/ and has root SSH. Tested with Ubuntu 24.04, 4 GB RAM, 2 vCPUs, 20 GB disk.

**Check before running the playbook**

1. VM can reach the repo (from laptop, as oneadmin):
   ```bash
   onevm ssh <VM_ID> --cmd "ping -c2 5.2.88.196"
   onevm ssh <VM_ID> --cmd "curl -sI http://5.2.88.196/repo/"
   ```
   Ping uses the host; curl uses the URL. If ping fails, run on the OpenNebula host: `sudo ./poc/cognit/scripts/enable-vm-repo-access.sh`

2. Inventory: in `poc/cognit/inventory.yml` set `ansible_host` under `frontend.hosts.f1` to your VM IP.

**Run the playbook** (from one-deploy repo root):

```bash
pyenv shell ansible-6.0.0
ansible-playbook -i poc/cognit/inventory.yml poc/cognit/playbook.yml
```

**Check it worked**

- Repo: `onevm ssh <VM_ID> --cmd "cat /etc/apt/sources.list.d/cognit.list"`
- Package: `onevm ssh <VM_ID> --cmd "dpkg -l opennebula-cognit-frontend"`

Different package from same repo: `ansible-playbook -i poc/cognit/inventory.yml poc/cognit/playbook.yml -e cognit_package=your-package`
