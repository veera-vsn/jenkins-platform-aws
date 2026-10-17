#!/bin/bash
# Agent bootstrap = "Phase 1: prepare the agent".
# Java (same major version as controller), jenkins user, controller public key, Docker,
# agent root on its own EBS volume.
set -euxo pipefail
exec > /var/log/user-data.log 2>&1

apt-get update -y
apt-get install -y openjdk-21-jre-headless git maven docker.io
systemctl enable --now docker

# Mount the separate EBS volume at /home/jenkins (Nitro instances expose it as nvme1n1)
DEV=$(lsblk -dpno NAME,MOUNTPOINT | awk '$2=="" && $1!~/nvme0n1/ {print $1}' | head -n1)
if [ -n "$DEV" ]; then
  mkfs.ext4 -F "$DEV"
  mkdir -p /home/jenkins
  echo "$DEV /home/jenkins ext4 defaults,nofail 0 2" >> /etc/fstab
  mount -a
fi

# jenkins user + controller public key in authorized_keys
id jenkins || useradd -m -d /home/jenkins -s /bin/bash jenkins
usermod -aG docker jenkins
mkdir -p /home/jenkins/.ssh
echo "${controller_pubkey}" > /home/jenkins/.ssh/authorized_keys
chmod 700 /home/jenkins/.ssh
chmod 600 /home/jenkins/.ssh/authorized_keys
chown -R jenkins:jenkins /home/jenkins
