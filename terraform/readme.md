<!-- @format -->

# Terraform Deployment for Laravel & MySQL Private Infra

## Resource Dideploy

- VPC dengan 2 subnet (public & private)
- NAT Gateway
- Internet Gateway
- Security Group (terpisah untuk masing-masing layanan)
- EC2 Instance:
  - Bastion (public)
  - Nginx (public)
  - Laravel (private)
  - MySQL (private)

## Variabel Penting

Semua variabel dapat ditambahkan ke `terraform.tfvars` atau `variables.tf`.

## Perintah

```bash
terraform init
terraform apply
```
