# AWS ECS Nginx Web Application

This repository contains the infrastructure and container configuration for deploying an Nginx web application onto **AWS ECS Fargate** within a private subnet. The application is secured and accelerated globally behind an **AWS Application Load Balancer (ALB)**.

## 🏗️ Architecture Overview
[ Internet ] ➔[ Public Subnet: ALB ]
│
▼ (VPC Internal Routing on Port 8008)
[ Private Subnet: ECS Fargate Task ]
[       (Nginx on Alpine Linux)    ]



* **Application Load Balancer (ALB):** Sits in public subnets to receive proxied traffic from the internet and routes it down to the private subnet targets.
* **AWS ECS Fargate:** Runs the serverless container tasks using `awsvpc` network mode. Tasks live inside a private subnet and have no public IP addresses.
* **Target Group Config:** Configured with `target_type = "ip"` routing directly to the dynamic private IPs assigned to the Fargate task network interfaces.
* **Virtual Private Cloud (VPC):** A custom VPC is created, it contains all the networking resources for both private and public connections. This is where all the SGs, route tables, internet-gateway, NAT-gateway, all the subnets and the 2 AZs are.

---

## 📦 Container Configuration

The application uses an optimized `nginx:alpine` image customized to bind to port **8008** (to align with the target group settings) and serves static web assets.

### Dockerfile Highlights
* Modifies Nginx's `default.conf` file in-place using `sed` to change the listening port from `80` to `8008`.
* Wipes out default Nginx landing pages to prevent configuration drift.
* Dynamically builds or copies repository web files via standard `.dockerignore` whitelisting rules.

To build and test the container locally:
```bash
# Build the container image
docker build -t my-nginx-app:latest .

# Run the container locally mapping host port 8008 to container port 8008
docker run -d -p 8008:8008 my-nginx-app:latest
```

---

## 📦 remote state backend (S3 bucket with versioning and encryption)

This repository houses the configuration and operational documentation for a secure **Amazon S3 (Simple Storage Service) bucket**. The bucket is engineered to follow security best practices by strictly enforcing **Object Versioning** and **Server-Side Encryption (SSE)** with S3 native locking.

It houses the tfstate files securely.

---

## 🛠️ Terraform Infrastructure Map

The infrastructure is written entirely in Terraform. Below are the key configuration alignment specifications used to stitch the network and security elements together.

### 1. Port Integration
To avoid standard `502 Bad Gateway` loops, ports must be consistently mapped as **integers** across the entire pipeline:
* **Nginx Process:** Port `8008`
* **Task Definition (`containerPort`):** Port `8008`
* **ECS Service (`container_port`):** Port `8008`
* **ALB Target Group (`port`):** Port `8008`

### 2. Security Group Blueprint
Traffic is tightly restricted so that Fargate tasks accept requests **exclusively** from the load balancer.

* **ALB Security Group:** Allows inbound HTTP/HTTPS from Cloudflare IP ranges (`0.0.0.0/0` during initial setup) and outbound traffic to the ECS Task Security Group.
* **ECS Task Security Group:** Drops all outside incoming connections. It explicitly allows ingress *only* from the ALB Security Group ID on port `8008`:

```hcl
ingress {
  from_port       = var.container_port # 8008
  to_port         = var.container_port # 8008
  protocol        = "tcp"
  security_groups = [aws_security_group.alb_sg.id] # Locks down to ALB only
}
```


---

## 🚀 Troubleshooting and Health Checks

If tasks are cycling or flagging as `Unhealthy`, verify the Target Group status:

* **HTTP 404 Status:** The load balancer is reaching Nginx, but Nginx cannot find the specific health path. Ensure your `aws_lb_target_group` health check path is configured to match your active codebase (typically `/` if serving a standard root index).
* **HTTP 403 Status:** Nginx is running but cannot locate an `index.html` file inside `/usr/share/nginx/html`. Verify your `.dockerignore` file isn't accidentally blocking your static website files from being copied over during `docker build`.
* **ServiceSchedulerInitiated Stops:** If tasks are being actively terminated with this stop code, increase the `health_check_grace_period_seconds` (recommended: `90`) inside your `aws_ecs_service` block to give the Nginx task enough time to safely initialize before the load balancer begins probing it.