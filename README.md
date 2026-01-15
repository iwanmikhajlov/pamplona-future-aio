# Pamplona Future All-in-One

Fork with pretty menu and plug-and-play dockerization for easy local server setup

<img width="704" height="458" alt="menu" src="https://github.com/user-attachments/assets/4ab3b48f-3f74-4472-891e-862817245dca" />

---

## Quick Start

### Prerequisites

1. **Download and Install Docker Desktop**
   https://www.docker.com/

   **Important:** Select WSL2 option during installation

   **Reboot** your PC after installation completes

### Installation

2. **Open PowerShell** and run:

   ```powershell
   irm https://oomchiller.github.io/pamplona-future-aio/server.ps1 | iex
   ```

3. **Follow the menu** to install and configure the server
<img width="1280" height="907" alt="configuration" src="https://github.com/user-attachments/assets/c2ad5394-a58d-4927-aa7b-4db7a67aab88" />

<img width="929" height="396" alt="success" src="https://github.com/user-attachments/assets/c95638df-562e-4d29-a63f-b26ad4781c88" />

4. **Launch the game** and enjoy!
<img width="449" height="276" alt="{A76D9284-BAAE-4790-98DE-0E9A0A676A9B}" src="https://github.com/user-attachments/assets/f7713fac-58bf-48cc-b7c1-cbbbeca3c551" />

---

## Manual Setup

If you want to tinker it for some reason:

### Build you own image

Clone repo and edit dockerfile, use docker-compose and .env from upstream branch, etc.

```bash
git clone https://github.com/oomchiller/pamplona-future-aio
cd pamplona-future-aio
git checkout aio
docker build -t pamplona-future .
```

### Run manually

Replace `C:\path\to\game` with your actual game path:

```powershell
docker network create pamplona-net

docker run -d --name pamplona-future-db `
  --network pamplona-net `
  -e POSTGRES_USER=dbuser `
  -e POSTGRES_PASSWORD=changeme `
  -e POSTGRES_DB=dbname `
  postgres:17

docker run -d --name pamplona-future `
  --network pamplona-net `
  -p 3000:3000 -p 25565:25565 -p 42230:42230 `
  -e GATEWAY_PORT=3000 `
  -e BLAZE_PORT=25565 `
  -e POSTGRES_USER=dbuser `
  -e POSTGRES_PASSWORD=changeme `
  -e POSTGRES_DB=dbname `
  -e POSTGRES_HOSTNAME=pamplona-future-db `
  -e POSTGRES_PORT=5432 `
  -e HOSTNAME=localhost `
  -e GAME_PATH=/mitm_volume `
  -e USER_ID=2407107883 `
  -e PERSONA_ID=1011786733 `
  -e PERSONA_USERNAME=Player `
  -v "C:\path\to\game:/mitm_volume" `
  pamplona-future
```

### Useful commands

**View logs:**
```powershell
docker logs -f pamplona-future
```

**Stop and remove:**
```powershell
docker stop pamplona-future pamplona-future-db
docker rm pamplona-future pamplona-future-db
docker network rm pamplona-net
```

### Or install everyting completely from scratch w/o Docker

Go to server developer repositories, described in Credits section, clone both repos, deploy all dependencies, such as Node.js, PostgreSQL, then compile the server, and copy mitm .dll & .ini files into your game folder. For more info check README.md in following repos

---

## Credits

Huge respect to ploxxxy and everyone who participated in server development

**pamplona-future sources:** https://github.com/ploxxxy/pamplona-future

**catalyst-mitm sources:** https://github.com/ploxxxy/catalyst-mitm
