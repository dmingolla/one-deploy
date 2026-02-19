#!/usr/bin/env bash
# Run on the OpenNebula host that has the VM bridge (e.g. 172.20.0.1).
# Enables NAT so VMs on 172.20.0.0/24 can reach the repo at 5.2.88.196.
# Usage: sudo ./enable-vm-repo-access.sh

set -e

VM_NET="172.20.0.0/24"

echo "Enabling IPv4 forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward

if command -v iptables >/dev/null 2>&1; then
  if ! iptables -t nat -C POSTROUTING -s "$VM_NET" ! -d 172.20.0.0/16 -j MASQUERADE 2>/dev/null; then
    echo "Adding iptables MASQUERADE for $VM_NET..."
    iptables -t nat -A POSTROUTING -s "$VM_NET" ! -d 172.20.0.0/16 -j MASQUERADE
  else
    echo "NAT rule for $VM_NET already present."
  fi
else
  echo "iptables not found. If using nftables, add equivalent NAT for $VM_NET."
  exit 1
fi

echo "Done. From a VM test: ping -c2 5.2.88.196  or  curl -sI http://5.2.88.196/repo/"
