provider "aws" {
  region = "us-east-1"
}

data "aws_vpc" "default_react" {
  default = true
}

resource "aws_subnet" "new_subnet_react" {
  vpc_id            = data.aws_vpc.default_react.id
  cidr_block        = "172.31.96.0/20"
  map_public_ip_on_launch = true

  tags = {
    Name = "NewSubnet_react"
  }
}

resource "aws_security_group" "strapi_terra_sg_vishwesh_react" {
  name        = "strapi_terra_sg_vishwesh_react"
  description = "Security group for Strapi ECS tasks"
  vpc_id      = data.aws_vpc.default_react.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "REACT"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Strapi"
    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
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
    Name = "strapi_terra_sg_vishwesh_react"
  }
}

resource "aws_iam_role" "ecs_task_execution_role_react" {
  name = "ecsTaskExecutionRole_vishwesh_react"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_react" {
  role       = aws_iam_role.ecs_task_execution_role_react.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_cluster" "strapi_cluster_react" {
  name = "strapi-cluster-react"
}

resource "aws_ecs_task_definition" "strapi_task_react" {
  family                   = "strapi-task-react"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"

  container_definitions = jsonencode([
    {
      name      = "strapi"
      image     = "vishweshrushi/strapi:latest"
      essential = true
      portMappings = [
        {
          containerPort = 1337
          hostPort      = 1337
        }
      ]
    }
  ])

  execution_role_arn = aws_iam_role.ecs_task_execution_role_react.arn
  task_role_arn      = aws_iam_role.ecs_task_execution_role_react.arn
}

resource "aws_ecs_service" "strapi_service_react" {
  name            = "strapi-service-react"
  cluster         = aws_ecs_cluster.strapi_cluster_react.arn
  task_definition = aws_ecs_task_definition.strapi_task_react.arn
  desired_count   = 1
  enable_ecs_managed_tags = true

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  network_configuration {
    subnets          = [aws_subnet.new_subnet_react.id]
    security_groups  = [aws_security_group.strapi_terra_sg_vishwesh_react.id]
    assign_public_ip = true
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  depends_on = [
    aws_ecs_task_definition.strapi_task_react
  ]
}

resource "null_resource" "wait_for_eni_react" {
  depends_on = [aws_ecs_service.strapi_service_react]

  provisioner "local-exec" {
    command = "sleep 60"
  }
}

data "aws_network_interface" "interface_tags_react" {
  filter {
    name   = "tag:aws:ecs:serviceName"
    values = ["strapi-service-react"]
  }
  depends_on = [
    null_resource.wait_for_eni_react
  ]
}

output "public_ip_react" {
  value = data.aws_network_interface.interface_tags_react.association[0].public_ip
}

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "terra_key_strapi" {
  key_name   = "terra_key_strapi_react"
  public_key = tls_private_key.example.public_key_openssh
}

resource "aws_instance" "strapi_react" {
  depends_on      = [data.aws_network_interface.interface_tags_react]
  ami             = "ami-04a81a99f5ec58529"
  instance_type   = "t2.small"
  key_name        = aws_key_pair.terra_key_strapi.key_name
  security_groups = [aws_security_group.strapi_terra_sg_vishwesh_react.name]
  
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.example.private_key_pem
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt install nodejs npm -y",
      "npx create-react-app strapi-react-ui",
      "cd strapi-react-ui",
      "npm install",
      "npm run build",
      "rm src/App.js",
      "echo \"import React, { useState, useEffect } from 'react';\" > src/App.js",
      "echo \"import logo from './logo.svg';\" >> src/App.js",
      "echo \"import axios from 'axios';\" >> src/App.js",
      "echo \"import './App.css';\" >> src/App.js",
      "echo \"\" >> src/App.js",
      "echo \"function App() {\" >> src/App.js",
      "echo \"  const [contentData, setContentData] = useState(null);\" >> src/App.js",
      "echo \"\" >> src/App.js",
      "echo \"  useEffect(() => {\" >> src/App.js",
      "echo \"    axios.get('http://${data.aws_network_interface.interface_tags_react.association[0].public_ip}:1337/api/strapis')\" >> src/App.js",
      "echo \"      .then(response => {\" >> src/App.js",
      "echo \"        if (response.data && response.data.data && response.data.data.length > 0) {\" >> src/App.js",
      "echo \"          setContentData(response.data.data[0].attributes);\" >> src/App.js",
      "echo \"        }\" >> src/App.js",
      "echo \"      });\" >> src/App.js",
      "echo \"  }, []);\" >> src/App.js",
      "echo \"\" >> src/App.js",
      "echo \"  return (\" >> src/App.js",
      "echo \"    <div className='App'>\" >> src/App.js",
      "echo \"      <header className='App-header'>\" >> src/App.js",
      "echo \"        <img src={logo} className='App-logo' alt='logo' />\" >> src/App.js",
      "echo \"        {contentData && (\" >> src/App.js",
      "echo \"          <div>\" >> src/App.js",
      "echo \"            <h2>VISHWESH RUSHI</h2>\" >> src/App.js",
      "echo \"            <p>{contentData.vishwesh}</p>\" >> src/App.js",
      "echo \"          </div>\" >> src/App.js",
      "echo \"        )}\" >> src/App.js",
      "echo \"        <a\" >> src/App.js",
      "echo \"          className='App-link'\" >> src/App.js",
      "echo \"          href='https://reactjs.org'\" >> src/App.js",
      "echo \"          target='_blank'\" >> src/App.js",
      "echo \"          rel='noopener noreferrer'\" >> src/App.js",
      "echo \"        >\" >> src/App.js",
      "echo \"          Learn React\" >> src/App.js",
      "echo \"        </a>\" >> src/App.js",
      "echo \"      </header>\" >> src/App.js",
      "echo \"    </div>\" >> src/App.js",
      "echo \"  );\" >> src/App.js",
      "echo \"}\" >> src/App.js",
      "echo \"\" >> src/App.js",
      "echo \"export default App;\" >> src/App.js",
      "npm run build"
    ]
  }
  tags = {
    Name = "Strapi-nginx-deploy-vishwesh-react"
  }
}


resource "null_resource" "certbot_react" {
  depends_on = [aws_instance.strapi_react.Strapi-nginx-deploy-vishwesh-react]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.example.private_key_pem
      host        = aws_instance.strapi_react.public_ip
    }

    inline = [
      "sudo apt install nginx -y",
      "sudo rm /etc/nginx/sites-available/default",
      "sudo bash -c 'echo \"server {\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    listen 80 default_server;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    listen [::]:80 default_server;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    root /var/www/html;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    index index.html index.htm index.nginx-debian.html;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    server_name vishweshrushi-strapi.contentecho.in;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    location / {\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"        proxy_pass http://${data.aws_network_interface.interface_tags_react.association[0].public_ip}:1337;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    }\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"}\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"server {\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    listen 80;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    listen [::]:80;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    server_name vishweshrushi-reactapi.contentecho.in;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    location / {\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"        proxy_pass http://${aws_instance.strapi_react.public_ip}:3000;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    }\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    location /api/strapis {\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"        proxy_pass http://${aws_instance.strapi_react.public_ip}:3000;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    }\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"}\" >> /etc/nginx/sites-available/default'",
      "sudo systemctl restart nginx"
    ]
  }
}

resource "aws_route53_record" "vishweshrushi-strapi" {
  zone_id = "Z06607023RJWXGXD2ZL6M"
  name    = "vishweshrushi-strapi.contentecho.in"
  type    = "A"
  ttl     = 300
  records = [data.aws_network_interface.interface_tags_react.association[0].public_ip]
}

resource "aws_route53_record" "vishweshrushi-reactapi" {
  zone_id = "Z06607023RJWXGXD2ZL6M"
  name    = "vishweshrushi-reactapi.contentecho.in"
  type    = "A"
  ttl     = 300
  records = [aws_instance.strapi_react.public_ip]
}


output "private_key" {
  value     = tls_private_key.example.private_key_pem
  sensitive = true
}

output "instance_ip" {
  value = aws_instance.strapi_react.public_ip
}

output "subdomain_url_strapi" {
  value = "http://vishweshrushi-strapi.contentecho.in"
}

output "subdomain_url_react" {
  value = "http://vishweshrushi-reactapi.contentecho.in"
}
