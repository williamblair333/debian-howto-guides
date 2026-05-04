
# Open WebUI with Ollama: Full Setup, Troubleshooting, and Usage Guide

> **Purpose**: This is designed to be a quick setup guide, reference manual, and troubleshooting resource for deploying Open WebUI with Ollama using Docker Compose.

---

## 📦 Prerequisites

- Docker Engine & Docker Compose installed
- Modern Linux distro (Debian preferred)
- Optional: NVIDIA GPU (for accelerated inference)

---

## 🚀 Quickstart Setup

### 1. Clone This Project
```bash
git clone open-webui
cd open-webui
```

### 2. Create Volumes
```bash
mkdir -p ./open-webui ./ollama
```

### 3. Launch the Stack
```bash
docker compose up -d
```

Wait ~60 seconds. Then visit: [http://localhost:48080](http://localhost:48080)

---

## 📄 `docker-compose.yml`
```yaml
#the docker-compose.yaml / yml may be different but I know the it works
version: '3.8'

services:

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    # ports:
    #   - "3000:8080"       # All traffic now routed through 8080 or 48080
    network_mode: host
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal:11434
      - AIOHTTP_CLIENT_TIMEOUT_OPENAI_MODEL_LIST=60
      - PORT=48080         # Supposed to fix a bug somewhere - may not need
      - OLLAMA_DISCOVERY_FORCE_RELOAD=true
    volumes:
      - ./open-webui:/app/backend/data
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped

  ollama:
    image: ollama/ollama:latest
    # ports:
    #   - "11434:11434"
    network_mode: host
    volumes:
      - ./ollama:/root/.ollama
    restart: unless-stopped
```

---

## 🤖 Add Models to Ollama

Run from host:
```bash
docker exec -it openwebui-ollama-1 ollama pull dolphin3
```

Or in the container:
```bash
ollama pull mistral
```

Open WebUI will auto-discover models if:
- `OLLAMA_DISCOVERY_FORCE_RELOAD=true` is set
- Models are located in `/root/.ollama`

If not:
- Go to **Settings > Connections > ⚙️ Ollama > Add Model ID** manually

---

## ⚙️ Manual Testing

Verify model API:
```bash
curl http://localhost:11434/api/tags
```

Test inference:
```bash
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model": "dolphin3", "prompt": "ping"}'
```

---

## 🛠️ Troubleshooting

### White screen after login
- Confirm models are pulled
- Check `/api/tags` is returning models
- Delete `./open-webui` and restart:
  ```bash
  docker compose down -v
  rm -rf ./open-webui
  docker compose up -d
  ```

### No models appear in dropdown
- Set `OLLAMA_DISCOVERY_FORCE_RELOAD=true`
- Check connection settings under Settings → Connections
- Add models manually by name

### Network issues
- `network_mode: host` works fine with `ports:` in practice, despite general Docker guidance
- Ensure `extra_hosts` includes:
  ```yaml
  - "host.docker.internal:host-gateway"
  ```
- All traffic should be directed to `http://localhost:48080`

---

## 📚 References

- [Open WebUI GitHub](https://github.com/open-webui/open-webui)
- [Ollama GitHub](https://github.com/ollama/ollama)

---

## ✍️ Notes for Maintainers

- This document is a live configuration reference.
- Always test models after pulling.
- Use the logs for diagnosis:
  ```bash
  docker logs -f openwebui-open-webui-1
  docker logs -f openwebui-ollama-1
  ```

---

## 🧪 Sample Models to Try

| Name       | Description           | Link |
|------------|------------------------|------|
| `dolphin3` | General purpose (uncensored) | [HF Page](https://huggingface.co/cognitivecomputations/dolphin-2.6-mistral-7b-dpo-ollama) |
| `mistral`  | Balanced 7B model      | [Ollama Model List](https://ollama.com/library) |
| `llama3`   | Meta’s open model      | [Meta LLaMA](https://ai.meta.com/llama/) |

---

## ✅ Final Checklist

- [x] Docker containers running
- [x] Model pulled via `ollama pull`
- [x] Model appears in UI
- [x] Test chat completes via UI or `curl`

> If all checkboxes ✅, deployment is successful.

---

*Maintained by: William Blair*

---

## 🔄 Update Instructions

To update models:
```bash
docker exec -it openwebui-ollama-1 ollama pull <model>
```

To update images:
```bash
docker compose pull
  docker compose up -d
```
