# Harbor Private Docker Registry using Docker Compose

A beginner-friendly lab guide for installing Harbor, enabling HTTPS, creating projects and users, and pushing/pulling Docker images.

## Lab objectives

1. Install Harbor using Docker Compose.
2. Configure Harbor with HTTPS.
3. Create a project and a user.
4. Push and pull a Docker image.
5. Verify the repository and access permissions.

## Architecture

Docker client → HTTPS (TCP 443) → Harbor → project/repository → image tags

## Prerequisites

- Ubuntu 22.04 or 24.04 (or a compatible Linux host)
- 2 CPU cores minimum; 4 GB RAM minimum (8 GB recommended for a smoother lab)
- 20 GB free disk space
- Internet access to download Harbor and container images
- Docker Engine and Docker Compose plugin
- TCP 443 reachable from the Docker client
- A DNS name or hostname that resolves to the Harbor server

> Harbor is a multi-container application. Resource needs depend on usage. Check the current Harbor release documentation before production use.

## 1. Install Docker (if it is not already installed)

Run from **any directory**:

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-v2 curl wget openssl
sudo systemctl enable --now docker
docker --version
docker compose version
sudo systemctl status docker
```

If your Ubuntu release does not provide `docker-compose-v2`, install Docker Compose using the official Docker documentation for your Ubuntu release.

## 2. Download and extract Harbor

Run from **any directory**:

```bash
mkdir -p ~/harbor-install
cd ~/harbor-install
```

Download the latest release automatically:

```bash
LATEST=$(curl -fsSL https://api.github.com/repos/goharbor/harbor/releases/latest \
  | grep '"tag_name"' | cut -d '"' -f4)

echo "$LATEST"

wget "https://github.com/goharbor/harbor/releases/download/${LATEST}/harbor-online-installer-${LATEST}.tgz"
tar -xzf "harbor-online-installer-${LATEST}.tgz"
cd harbor
```

Check that the directory contains `harbor.yml.tmpl`, `install.sh`, and `prepare`:

```bash
pwd
ls -la
```

## 3. Configure Harbor

Run from **inside `~/harbor-install/harbor`**:

```bash
cp harbor.yml.tmpl harbor.yml
nano harbor.yml
```

Edit these settings:

```yaml
hostname: harbor.example.local

https:
  port: 443
  certificate: /etc/harbor/certs/harbor.crt
  private_key: /etc/harbor/certs/harbor.key

harbor_admin_password: CHANGE_THIS_TO_A_STRONG_PASSWORD
```

Important:
- `hostname` must be the DNS name or hostname that Docker clients use to reach Harbor.
- Do not use `127.0.0.1` as the hostname when clients connect from another machine.
- If using a private lab hostname, configure name resolution on **every client** (for example, a hosts-file entry pointing `harbor.example.local` to the Harbor server IP).
- Keep `harbor.yml` and passwords out of public Git repositories.
- Check the sample configuration for any other required settings for the Harbor release you downloaded.

## 4. Create a self-signed certificate for a lab

For a lab only, create the certificate on the Harbor server.

Run from **any directory**. Replace `HARBOR_IP` with the Harbor server's reachable IP address and `harbor.example.local` with the exact hostname used by clients:

```bash
HARBOR_IP="192.0.2.10"
HARBOR_HOST="harbor.example.local"

sudo mkdir -p /etc/harbor/certs

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/harbor/certs/harbor.key \
  -out /etc/harbor/certs/harbor.crt \
  -subj "/CN=${HARBOR_HOST}" \
  -addext "subjectAltName=DNS:${HARBOR_HOST},IP:${HARBOR_IP}"

sudo chmod 600 /etc/harbor/certs/harbor.key
sudo chmod 644 /etc/harbor/certs/harbor.crt
sudo ls -l /etc/harbor/certs/
```

The IP above is an example from the documentation range. Replace it with your actual Harbor server IP.

For production, use a certificate issued by a trusted CA and follow your organization's certificate-management process.

## 5. Configure name resolution

On the Harbor server and each client that will access Harbor, make the hostname resolve to the Harbor server's IP.

For a temporary lab, add a line to `/etc/hosts` on each relevant machine:

```text
192.0.2.10 harbor.example.local
```

Replace the example IP with the real server IP.

Test on the client:

```bash
getent hosts harbor.example.local
```

## 6. Install Harbor

Run from **inside `~/harbor-install/harbor`**:

```bash
sudo ./install.sh
```

Wait for the installation to finish. Then check:

```bash
sudo docker compose ps
sudo docker ps
curl --cacert /etc/harbor/certs/harbor.crt \
  https://harbor.example.local/api/v2.0/health
```

If the certificate is not trusted by the machine running `curl`, the health check may fail with a certificate verification error. For a one-time diagnostic only, use `curl -k`; do not treat that as a production TLS solution.

## 7. Trust the lab certificate on each Docker client

Docker must trust the CA/certificate for the registry hostname. On each Docker client:

```bash
sudo mkdir -p /etc/docker/certs.d/harbor.example.local
```

Copy the Harbor certificate securely from the Harbor server to the client and save it as:

```text
/etc/docker/certs.d/harbor.example.local/ca.crt
```

If Harbor uses a non-default HTTPS port, include the port in the directory name, for example `harbor.example.local:8443`.

Then restart Docker:

```bash
sudo systemctl restart docker
```

Do not copy or distribute the private key (`harbor.key`) to clients.

## 8. Create a project and user in Harbor

1. Open `https://harbor.example.local` in a browser.
2. Sign in as `admin` using the password configured in `harbor.yml`.
3. Change the initial admin password if it has not already been changed.
4. Go to **Projects → New Project**.
5. Create a project named `devops-project`. Choose **Private** for this lab.
6. Go to **Administration → Users → New User** and create `devopsuser`.
7. Open **Projects → devops-project → Members**.
8. Add `devopsuser` with the **Developer** role so the user can push and pull images.

Use a unique strong password. The example username is for documentation; do not publish real passwords.

## 9. Push an image to Harbor

Run on a Docker client that trusts the Harbor certificate and can resolve the Harbor hostname.

```bash
docker pull nginx:latest
docker login harbor.example.local
```

Enter the Harbor username and password when prompted. Then tag and push:

```bash
docker tag nginx:latest harbor.example.local/devops-project/nginx:v1
docker push harbor.example.local/devops-project/nginx:v1
```

Expected result: Docker reports a successful push and prints an image digest.

## 10. Pull the image from Harbor

```bash
docker pull harbor.example.local/devops-project/nginx:v1
docker images
```

To demonstrate that the image is fetched again, you may remove only the Harbor-tagged local copy first:

```bash
docker rmi harbor.example.local/devops-project/nginx:v1
docker pull harbor.example.local/devops-project/nginx:v1
```

## 11. Verify in the Harbor UI

1. Sign in to Harbor as `devopsuser`.
2. Open **Projects → devops-project**.
3. Open **Repositories**.
4. Confirm the `nginx` repository exists.
5. Open it and confirm tag `v1` is present.

## 12. Service status and useful commands

Run these commands from **inside `~/harbor-install/harbor`**, where the generated `docker-compose.yml` is located:

```bash
sudo docker compose ps
sudo docker compose logs --tail=50
sudo docker compose logs -f
sudo docker compose restart
```

Run from **any directory**:

```bash
docker --version
docker compose version
docker images
docker login harbor.example.local
docker pull nginx:latest
```

## Directory guide

```text
/home/ubuntu/
└── harbor-install/
    ├── harbor-online-installer-<version>.tgz
    └── harbor/
        ├── harbor.yml
        ├── harbor.yml.tmpl
        ├── install.sh
        ├── prepare
        └── docker-compose.yml   # generated during installation

/etc/harbor/certs/
├── harbor.crt
└── harbor.key
```

## Troubleshooting

| Symptom | Checks |
|---|---|
| Browser cannot open Harbor | Confirm Harbor containers are running; check DNS/hosts entry and TCP 443 firewall/security-group rules. |
| `connection refused` | Check `sudo docker compose ps`, `sudo ss -tlnp \| grep :443`, and server firewall/security group. |
| `no such host` | Confirm the hostname resolves on the client using `getent hosts harbor.example.local`. |
| `x509: certificate signed by unknown authority` | Install the certificate/CA on the Docker client under `/etc/docker/certs.d/<hostname>/ca.crt`, then restart Docker. |
| `unauthorized` or login failure | Check username/password and account status. |
| `denied: requested access to the resource is denied` | Check the project name, repository path, and that the user has Developer or higher project permissions. |
| Push fails | Confirm login, project exists, user role allows push, hostname and TLS are correct, and disk space is available. |
| Containers unhealthy | Run `sudo docker compose logs --tail=100` from the Harbor directory. |

## Security notes

- Do not commit `harbor.yml`, passwords, access tokens, `harbor.key`, or private credentials to GitHub.
- Use trusted CA certificates in production.
- Restrict network access to the registry.
- Use unique passwords and least-privilege project roles.
- Back up Harbor data and configuration before upgrades or maintenance.
- Follow the official Harbor documentation for production deployment, upgrades, backups, and supported configuration.

## Submission evidence checklist

- [ ] Harbor installation completed
- [ ] HTTPS configuration (hide secrets)
- [ ] Harbor containers running (`docker compose ps`)
- [ ] Project created
- [ ] User created and added as Developer
- [ ] Docker login successful
- [ ] Image push successful
- [ ] Image pull successful
- [ ] Repository and `v1` tag visible in Harbor UI
- [ ] GitHub README documentation

## Official references

- Harbor documentation: https://goharbor.io/docs/
- Harbor releases: https://github.com/goharbor/harbor/releases
- Docker documentation: https://docs.docker.com/
