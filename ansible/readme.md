<!-- @format -->

# Ansible Configuration for Laravel & MySQL Deployment

## Struktur Role

- `mysql`: Instalasi MySQL + konfigurasi user
- `phpmyadmin`: Instalasi phpMyAdmin
- `laravel`: Deploy Laravel project (clone, .env, composer, migrate)
- `nginx_proxy_laravel`: Setup Nginx reverse proxy SSL untuk Laravel
- `nginx_proxy_phpmyadmin`: Setup reverse proxy ke private phpMyAdmin

## Jalankan Ansible

```bash
ansible-playbook -i inventories/production/all_host.ini playbook/site.yaml
```

bastion
ssh-copy-id -f "-o IdentityFile ../main-key2.pem" ubuntu@54.206.64.117

di server private
khusus untuk proxy nginx proxy gunakan ip priovate bukan ip public
ssh-copy-id -f "-o IdentityFile ./main-key2.pem" ubuntu@10.0.1.96

2ip private
ssh-copy-id -f "-o IdentityFile ./main-key2.pem" ubuntu@10.0.2.38
ssh-copy-id -f "-o IdentityFile ./main-key2.pem" ubuntu@10.0.2.157

lalu ketika sudah maka copy di bagian now loging itu bisa untuk sekali masuk tanpa menggunkan key lagi

masukan hanya
ssh ubuntu@ip

langsung masuk

======
jika tidak bisa dan ERROR: No identities found

chmod 600 ./main-key2.pem

ssh-keygen

enter enter dan enter

contoh =

ssh -J ubuntu@54.206.64.117 ubuntu@10.0.2.38
