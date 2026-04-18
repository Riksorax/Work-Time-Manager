# Server Setup - Agent 11

Run these commands on the Hetzner server to prepare for deployment.

## 1. Create Project Directory
```bash
sudo mkdir -p /opt/work-time-manager-web
sudo chown $USER:$USER /opt/work-time-manager-web
cd /opt/work-time-manager-web
```

## 2. Copy docker-compose.yml
Manually copy the `docker-compose.yml` from the `web/` directory to `/opt/work-time-manager-web/docker-compose.yml` on the server.

## 3. Ensure Traefik Proxy Network exists
```bash
docker network create traefik-proxy || true
```

## 4. Setup Deploy User (Optional but recommended)
It is recommended to use a dedicated deployment user instead of root.
```bash
sudo adduser --disabled-password deploy
sudo usermod -aG docker deploy
sudo mkdir -p /home/deploy/.ssh
sudo cp /root/.ssh/authorized_keys /home/deploy/.ssh/
sudo chown -R deploy:deploy /home/deploy/.ssh
```

## 5. First Run
Once the GitHub Action has pushed the first image, you can start it manually to test:
```bash
IMAGE_TAG=latest docker compose up -d
```
