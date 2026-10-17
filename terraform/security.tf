# Controller: UI (8080) and SSH only from your IP.
resource "aws_security_group" "controller" {
  name        = "jenkins-controller-sg"
  description = "Jenkins controller"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Jenkins UI from my IP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "jenkins-controller-sg" }
}

# Agents: port 22 ONLY from the controller's security group (interview point:
# "SG allows 22 from the controller SG only"). No public access at all.
resource "aws_security_group" "agent" {
  name        = "jenkins-agent-sg"
  description = "Jenkins agents"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH from controller only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.controller.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "jenkins-agent-sg" }
}
