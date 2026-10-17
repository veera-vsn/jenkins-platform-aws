#!/bin/bash
# Controller bootstrap: Java 21 + Jenkins LTS + AWS CLI + nightly JENKINS_HOME backup to S3.
set -euxo pipefail
exec > /var/log/user-data.log 2>&1

apt-get update -y
apt-get install -y fontconfig openjdk-21-jre-headless curl unzip gnupg

# Jenkins LTS repo. If apt complains about the key, check https://pkg.jenkins.io/debian-stable/
# for the current key file name and update the URL below.
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
  -o /usr/share/keyrings/jenkins-keyring.asc
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  > /etc/apt/sources.list.d/jenkins.list
apt-get update -y
apt-get install -y jenkins
systemctl enable --now jenkins

# AWS CLI v2 (uses the instance's IAM role, no keys on disk)
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp && /tmp/aws/install

# Nightly backup of JENKINS_HOME to S3 at 02:00 (H-style spread not needed for one job).
# Includes secrets/ together with credentials.xml, otherwise restored credentials can't be decrypted.
# Excludes workspace/ and caches (rebuildable, large).
cat > /usr/local/bin/jenkins-backup.sh <<'BACKUP'
#!/bin/bash
set -euo pipefail
TS=$(date +%Y%m%d-%H%M%S)
ARCHIVE=/tmp/jenkins-home-$TS.tar.gz
tar -czf "$ARCHIVE" -C /var/lib \
  --exclude='jenkins/workspace' \
  --exclude='jenkins/caches' \
  --exclude='jenkins/.cache' \
  jenkins
aws s3 cp "$ARCHIVE" "s3://${backup_bucket}/jenkins-home/$TS.tar.gz"
rm -f "$ARCHIVE"
echo "$(date) backup ok: $TS" >> /var/log/jenkins-backup.log
BACKUP
chmod 750 /usr/local/bin/jenkins-backup.sh
echo "0 2 * * * root /usr/local/bin/jenkins-backup.sh" > /etc/cron.d/jenkins-backup
