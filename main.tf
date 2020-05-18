provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

# --- IAM ---
resource "aws_iam_instance_profile" "s3_access_profile" {
  name = "s3_access"
  role = "${aws_iam_role.s3_access_role.name}"
}

resource "aws_iam_role_policy" "s3_access_policy" {
  name = "s3_access_policy"
  role = "${aws_iam_role.s3_access_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "s3_access_role" {
  name = "s3_access_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazon.aws.com"
      }
    }
  ]
}
EOF
}

# --- VPC ---

resource "aws_vpc" "wp_vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags {
    Name = "wp_vpc"
  }
}

# --- Network Routing ---

resource "aws_internet_gateway" "wp_igw" {
  vpc_id = "${aws_vpc.wp_vpc.id}"

  tags {
    Name = "wp_igw"
  }
}

resource "aws_route_table" "wp_public_rt" {
  vpc_id = "${aws_vpc.wp_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.wp_igw.id}"
  }

  tags {
    Name = "wp_public"
  }
}

resource "aws_default_route_table" "wp_private_rt" {
  default_route_table_id = "${aws_vpc.wp_vpc.default_route_table_id}"

  tags {
    Name = "wp_private"
  }
}

# --- Subnets ---

# The REPEAT EVERY SINGLE THING method :)
resource "aws_subnet" "wp_public1" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "${var.cidrs["public1"]}"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "wp_public1"
  }
}

resource "aws_subnet" "wp_public2" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "${var.cidrs["public2"]}"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "wp_public2"
  }
}

resource "aws_subnet" "wp_private1" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "${var.cidrs["private1"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "wp_private1"
  }
}

resource "aws_subnet" "wp_private2" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "${var.cidrs["private2"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "wp_private2"
  }
}

resource "aws_subnet" "wp_rds1" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "${var.cidrs["rds1"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "wp_rds2"
  }
}

resource "aws_subnet" "wp_rds2" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "${var.cidrs["rds2"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "wp_rds2"
  }
}

resource "aws_subnet" "wp_rds3" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "${var.cidrs["rds3"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[2]}"

  tags {
    Name = "wp_rds3"
  }
}

resource "aws_db_subnet_group" "wp_rds_subnet_group" {
  name = "wp_rds_subnet_group"

  subnet_ids = [
    "${aws_subnet.wp_rds1.id}",
    "${aws_subnet.wp_rds2.id}",
    "${aws_subnet.wp_rds3.id}",
  ]

  tags {
    Name = "wp_rds_sng"
  }
}

resource "aws_route_table_association" "wp_public1_assoc" {
  subnet_id      = "${aws_subnet.wp_public1.id}"
  route_table_id = "${aws_route_table.wp_public_rt.id}"
}

resource "aws_route_table_association" "wp_public2_assoc" {
  subnet_id      = "${aws_subnet.wp_public2.id}"
  route_table_id = "${aws_route_table.wp_public_rt.id}"
}

# --- Security Groups ---

resource "aws_security_group" "wp_dev_sg" {
  name        = "wp_ev_sg"
  description = "Used for access to dev instances"
  vpc_id      = "${aws_vpc.wp_vpc.id}"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.localip}", "${var.cloudip}"]
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.localip}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "wp_public_sg" {
  name        = "wp_public_sg"
  description = "Used to provide public HTTP access to the ELB"
  vpc_id      = "${aws_vpc.wp_vpc.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "wp_private_sg" {
  name        = "wp_private_sg"
  description = "Used for private instances"
  vpc_id      = "${aws_vpc.wp_vpc.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "wp_rds_sg" {
  name        = "wp_rds_sg"
  description = "Used for RDS instances"
  vpc_id      = "${aws_vpc.wp_vpc.id}"

  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"

    security_groups = [
      "${aws_security_group.wp_dev_sg.id}",
      "${aws_security_group.wp_public_sg.id}",
      "${aws_security_group.wp_private_sg.id}",
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- VPC Endpoint for S3 ---

resource "aws_vpc_endpoint" "wp_private_s3_endpoint" {
  vpc_id       = "${aws_vpc.wp_vpc.id}"
  service_name = "com.amazonaws.${var.aws_region}.s3"

  route_table_ids = [
    "${aws_vpc.wp_vpc.default_route_table_id}",
    "${aws_route_table.wp_public_rt.id}",
  ]

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*",
      "Principal": "*"
    }
  ]
}
EOF
}

# --- S3 Bucket(s) ---

resource "random_id" "wp_s3_random" {
  byte_length = 2
}

resource "aws_s3_bucket" "wp_code_bucket" {
  bucket        = "${var.domain_name}-${random_id.wp_s3_random.dec}"
  acl           = "private"
  force_destroy = true

  tags {
    Name = "CodeBucket"
  }
}

# --- RDS ---

resource "aws_db_instance" "wp_db" {
  allocated_storage      = 10
  engine                 = "mysql"
  engine_version         = "5.6.27"
  instance_class         = "${var.db_instance_class}"
  name                   = "${var.db_name}"
  username               = "${var.db_user}"
  password               = "${var.db_password}"
  db_subnet_group_name   = "${aws_db_subnet_group.wp_rds_subnet_group.name}"
  vpc_security_group_ids = ["${aws_security_group.wp_rds_sg.id}"]
  skip_final_snapshot    = true
}

# --- Key Pair ---

resource "aws_key_pair" "wp_auth" {
  key_name   = "${var.key_name}"
  public_key = "${var.public_key_path}"
}

# --- Development Server ---

resource "aws_instance" "wp_dev" {
  instance_type          = "${var.dev_instance_type}"
  ami                    = "${var.dev_ami}"
  key_name               = "${aws_key_pair.wp_auth.id}"
  vpc_security_group_ids = ["${aws_security_group.wp_dev_sg.id}"]
  iam_instance_profile   = "${aws_iam_instance_profile.s3_access_profile.id}"
  subnet_id              = "${aws_subnet.wp_public1.id}"

  tags {
    Name = "wp_dev"
  }

  provisioner "local-exec" {
    command = <<EOD
cat <<EOF > inventory
[dev]
${aws_instance.wp_dev.public_ip}
[dev:vars]
s3code=${aws_s3_bucket.wp_code_bucket.bucket}
domain=${var.domain_name}
EOF
EOD
  }

  provisioner "local-exec" {
    command = "aws ec2 wait instance-status-ok --instance-ids ${aws_instance.wp_dev.id} --profile tfansible && ansible-playbook wordpress.yml"
  }
}

#  --- ELB ---

resource "aws_elb" "wp_elb" {
  name            = "${var.domain_name}"
  security_groups = ["${aws_security_group.wp_public_sg.id}"]

  subnets = [
    "${aws_subnet.wp_public1.id}",
    "${aws_subnet.wp_public2.id}",
  ]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = "${var.elb_healthy_threshold}"
    unhealthy_threshold = "${var.elb_unhealthy_threshold}"
    timeout             = "${var.elb_timeout}"
    target              = "TCP:80"
    interval            = "${var.elb_interval}"
  }

  connection_draining         = true
  connection_draining_timeout = 400
  cross_zone_load_balancing   = true
  idle_timeout                = 400

  tags {
    Name = "wp_${var.domain_name}-elb"
  }
}

# --- Golden AMI

resource "random_id" "wp_ami_random" {
  byte_length = 3
}

resource "aws_ami_from_instance" "wp_golden" {
  name               = "wp_ami-${random_id.wp_ami_random.b64}"
  source_instance_id = "${aws_instance.wp_dev.id}"

  provisioner "local-exec" {
    command = <<EOT
cat <<EOF > userdata
#!/bin/bash
/usr/bin/aws s3 sync s3://${aws_s3_bucket.wp_code_bucket.bucket} /var/www/html
/bin/touch /var/spool/root
sudo /bin/echo '*/5 * * * * aws s3 sync s3://${aws_s3_bucket.wp_code_bucket.bucket} /var/www/html' >> /var/spool/cron/root
EOF
EOT
  }
}
