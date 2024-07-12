provider "aws" {
  region = "ap-south-2"
}

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "terra_key_strapi" {
  key_name   = "terra_key_strapi"
  public_key = tls_private_key.example.public_key_openssh
}

resource "aws_security_group" "strapi_terra_sg_vishwesh" {
  name        = "strapi_terra_sg_vishwesh"
  description = "strapi_terra_sg_vishwesh"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Custom Port"
    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "strapi_terra_sg_vishwesh"
  }
}

resource "aws_instance" "web" {
  ami           = "ami-008616ec4a2c6975e"
  instance_type = "t3.small"
  key_name      = aws_key_pair.terra_key_strapi.key_name
  security_groups = [aws_security_group.strapi_terra_sg_vishwesh.name]
  
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.example.private_key_pem
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt install docker.io -y",
      "sudo usermod -aG docker ubuntu",
      "sudo docker pull vishweshrushi/strapi:latest",
      "sudo docker run -d -p 1337:1337 vishweshrushi/strapi:latest"
    ]
  }

  tags = {
    Name = "StrapiTerraformInstance"
  }
}

output "private_key" {
  value     = tls_private_key.example.private_key_pem
  sensitive = true
}

output "instance_ip" {
  value = aws_instance.web.public_ip
}
