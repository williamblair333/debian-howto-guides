# Docker Setup for MX Linux 25 (Trixie)

Quick and simple Docker installation for MX Linux 25 with systemd.

---

## Installation

### Remove Conflicts

```bash
sudo apt remove -y docker docker-engine docker.io containerd runc docker-compose-plugin docker-buildx-plugin
sudo apt autoremove -y
```

### Install Docker

```bash
sudo apt update
sudo apt install -y docker.io docker-compose docker-buildx
```

### Enable and Start

```bash
sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl status docker
```

### Add User to Docker Group

```bash
sudo usermod -aG docker $USER
newgrp docker
```

### Verify

```bash
docker --version
docker-compose --version
docker buildx version
docker run hello-world
```

---

## Quick Commands

```bash
# Container management
docker ps                    # List running containers
docker ps -a                 # List all containers
docker logs container-name   # View logs
docker exec -it name bash    # Shell into container

# Image management
docker images                # List images
docker pull image:tag        # Pull image
docker rmi image             # Remove image

# Build (with buildx)
docker buildx build -t name:tag .
docker buildx ls             # List builders

# Cleanup
docker system prune -a       # Remove unused data
docker volume prune          # Remove unused volumes

# Compose
docker-compose up -d         # Start services
docker-compose down          # Stop services
docker-compose logs -f       # View logs
```

---

## Troubleshooting

**Permission denied?**

```bash
sudo usermod -aG docker $USER
newgrp docker
```

**Service not running?**

```bash
sudo systemctl start docker
sudo systemctl status docker
```

**Out of space?**

```bash
docker system df
docker system prune -a --volumes
```

---

Done. That's it.
