provider "aws" {
  region = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_subnet" "new_subnet" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.96.0/20"
  map_public_ip_on_launch = true

  tags = {
    Name = "NewSubnet"
  }
}

resource "aws_security_group" "strapi_terra_sg_vishwesh" {
  name        = "strapi_terra_sg_vishwesh"
  description = "Security group for Strapi ECS tasks"
  vpc_id      = data.aws_vpc.default.id

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
    Name = "strapi_terra_sg_vishwesh"
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole_vishwesh"

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

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_cluster" "strapi_cluster" {
  name = "strapi-cluster"
}

resource "aws_ecs_task_definition" "strapi_task" {
  family                   = "strapi-task"
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

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_ecs_service" "strapi_service" {
  name            = "strapi-service"
  cluster         = aws_ecs_cluster.strapi_cluster.arn
  task_definition = aws_ecs_task_definition.strapi_task.arn
  desired_count   = 1
  enable_ecs_managed_tags = true

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  network_configuration {
    subnets          = [aws_subnet.new_subnet.id]
    security_groups  = [aws_security_group.strapi_terra_sg_vishwesh.id]
    assign_public_ip = true
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  depends_on = [
    aws_ecs_task_definition.strapi_task
  ]
}

resource "null_resource" "wait_for_eni" {
  depends_on = [aws_ecs_service.strapi_service]

  provisioner "local-exec" {
    command = "sleep 60"
  }
}

data "aws_network_interface" "interface_tags" {
  filter {
    name   = "tag:aws:ecs:serviceName"
    values = ["strapi-service"]
  }
  depends_on = [
    null_resource.wait_for_eni
  ]
}

output "public_ip" {
    value = data.aws_network_interface.interface_tags.association[0].public_ip
}

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "terra_key_strapi" {
  key_name   = "terra_key_strapi"
  public_key = tls_private_key.example.public_key_openssh
}

resource "aws_instance" "strapi" {
  depends_on = [data.aws_network_interface.interface_tags]
  ami           = "ami-04a81a99f5ec58529"
  instance_type = "t2.small"
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
    "echo \"    axios.get('http://${data.aws_network_interface.interface_tags.association[0].public_ip}:1337/api/strapis')\" >> src/App.js",
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
    "npm start"
    ]
  }
  tags = {
    Name = "Strapi-nginx-deploy-vishwesh_react"
  }
}

resource "null_resource" "certbot" {
  depends_on = [aws_instance.strapi.Strapi-nginx-deploy-vishwesh_react]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.example.private_key_pem
      host        = aws_instance.strapi.public_ip
    }

    inline = [
      "sudo apt install nginx -y",
      "sudo rm /etc/nginx/sites-available/default",
      "sudo bash -c 'echo \"server {\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    listen 80 default_server;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    listen [::]:80 default_server;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    root /var/www/html;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    index index.html index.htm index.nginx-debian.html;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    server_name vishweshrushi.contentecho.in;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    location / {\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"        proxy_pass http://${data.aws_network_interface.interface_tags.association[0].public_ip}:1337;\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"    }\" >> /etc/nginx/sites-available/default'",
      "sudo bash -c 'echo \"}\" >> /etc/nginx/sites-available/default'",
      "sudo systemctl restart nginx"
    ]
  }
}

resource "aws_route53_record" "vishweshrushi" {
  zone_id = "Z06607023RJWXGXD2ZL6M"
  name    = "vishweshrushi.contentecho.in"
  type    = "A"
  ttl     = 300
  records = [aws_instance.strapi.public_ip]
}

resource "aws_route53_record" "vishweshrushi-api" {
  zone_id = "Z06607023RJWXGXD2ZL6M"
  name    = "vishweshrushi-api.contentecho.in"
  type    = "A"
  ttl     = 300
  records = [${data.aws_network_interface.interface_tags.association[0].public_ip}]
}
resource "null_resource" "certbot" {
  depends_on = [aws_route53_record.vishweshrushi]
  depends_on = [aws_route53_record.vishweshrushi-api]
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.example.private_key_pem
      host        = aws_instance.strapi.public_ip
    }

    inline = [
      "sudo apt install certbot python3-certbot-nginx -y",
      "sudo certbot --nginx -d vishweshrushi.contentecho.in --non-interactive --agree-tos -m rushivishwesh02@gmail.com"
      "sudo certbot --nginx -d vishweshrushi-api.contentecho.in --non-interactive --agree-tos -m rushivishwesh02@gmail.com"
    ]
  }
}

output "private_key" {
  value     = tls_private_key.example.private_key_pem
  sensitive = true
}

output "instance_ip" {
  value = aws_instance.strapi.public_ip
}

output "subdomain_url" {
  value = "http://vishweshrushi.contentecho.in"
}

output "subdomain_url" {
  value = "http://vishweshrushi-api.contentecho.in"
}
