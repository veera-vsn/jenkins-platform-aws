# P1: Production-style Jenkins on AWS (Terraform)

Jenkins controller in a public subnet (0 executors), build agents in a private subnet
connected over SSH, separate EBS volume for agent workspaces, nightly JENKINS_HOME backup to an
encrypted, versioned S3 bucket using an IAM role (no access keys on the server).

## Architecture
- VPC 10.20.0.0/16: public subnet (controller, NAT gateway), private subnet (agents)
- Controller SG: 8080 + 22 from my IP only
- Agent SG: 22 **from the controller SG only**, no public IP
- Agents reach the internet (apt, Maven Central, Docker Hub) via the NAT gateway
- Terraform generates the controller→agent SSH key pair (ED25519)

## Run
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # fill in key_name and my_ip_cidr (curl ifconfig.me)
terraform init
terraform fmt && terraform validate
terraform plan -out tfplan
terraform apply tfplan
terraform output jenkins_url
terraform output -raw agent_ssh_private_key      # for the Jenkins credential
```
Wait ~3 minutes for user-data to finish (`sudo tail -f /var/log/user-data.log` on the controller).

## Configure Jenkins (do it by hand the first time: this is the interview answer)
1. Unlock: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`; install suggested plugins; create an admin user.
2. **Built-in node → executors = 0.** (Manage Jenkins → Nodes → Built-In Node → Configure)
3. **Credential:** Manage Jenkins → Credentials → Global → *SSH Username with private key*,
   ID `agent-ssh`, username `jenkins`, paste the private key.
4. **Node:** Nodes → New Node `agent-1` (Permanent): remote root `/home/jenkins`, executors `2`,
   labels `linux docker maven`, launch *via SSH*, host = agent private IP, credential `agent-ssh`,
   host key verification: *Known hosts* (ssh-keyscan the agent from the controller first) or
   *Manually trusted* for the lab.
5. **Verify:** agent log shows "Agent successfully connected and online".
6. Run a test pipeline (below) and confirm it runs on `agent-1`, never on the controller.

```groovy
pipeline {
    agent { label 'linux && docker' }
    options {
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timeout(time: 15, unit: 'MINUTES')
    }
    stages {
        stage('Where am I') {
            steps {
                sh 'hostname; whoami; java -version; df -h /home/jenkins; docker version'
            }
        }
    }
    post { always { cleanWs() } }
}
```

## Backup and restore test
```bash
sudo /usr/local/bin/jenkins-backup.sh          # run once by hand
aws s3 ls s3://$(terraform output -raw backup_bucket)/jenkins-home/
```
Restore drill: stop Jenkins → download the archive → extract over /var/lib → `chown -R jenkins:jenkins
/var/lib/jenkins` → start Jenkins → confirm jobs, nodes and credentials still work.
`secrets/` must be restored together with `credentials.xml`.

## Cost / cleanup
NAT gateway + t3.medium + t3.small ≈ a few euro per day. **Always destroy after the session:**
```bash
terraform destroy
```

## Interview talking points this project proves
- Why the controller has 0 executors (stability, security, scalability)
- SSH agent setup: agent prep → Jenkins credential + node → network (22 from controller SG only) → verify
- Reachability: agent has only a private IP; controller reaches it inside the VPC
- Separate EBS for workspaces so a full workspace disk can't take down the OS
- JENKINS_HOME backup incl. secrets/ + credentials.xml; S3 versioning, encryption, lifecycle; IAM role, no keys
- buildDiscarder, timeout, cleanWs in every pipeline

## Next phases
- Phase 2: Ansible for controller/agent configuration (replace user-data), JCasC for nodes and credentials
- Phase 3: Prometheus node_exporter + 80% disk alert (feeds P4)
