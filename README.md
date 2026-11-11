---
title: ListCloud OpenList
emoji: ☁️
colorFrom: blue
colorTo: indigo
sdk: docker
app_port: 7860
pinned: false
license: agpl-3.0
---

# ☁️ ListCloud — 100% Free, Zero-Credit-Card 24/7 Cloud Hosting for OpenList

[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL%203.0-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Powered by OpenList](https://img.shields.io/badge/Powered%20By-OpenList-00b4d8)](https://github.com/OpenListTeam/OpenList)
[![Deploy on Hugging Face Spaces](https://img.shields.io/badge/%F0%9F%A4%97%20Deploy%20to-HF%20Spaces%20(Free%2016GB%20RAM)-yellow)](https://huggingface.co/new-space?template=Protegee1505/listcloud)
[![Deploy to Render](https://img.shields.io/badge/%E2%9A%A1%20Deploy%20to-Render%20(Free)-46E3B7)](https://render.com/deploy?repo=https://github.com/Protegee1505/listcloud)
[![Deploy to Koyeb](https://img.shields.io/badge/%F0%9F%9A%80%20Deploy%20to-Koyeb%20(Free)-121212)](https://app.koyeb.com/deploy?type=git&repository=github.com/Protegee1505/listcloud&branch=main&name=listcloud)

**ListCloud** lets anyone deploy and host their own **instant or custom [OpenList](https://github.com/OpenListTeam/OpenList)** instance on the cloud **100% free forever — with zero credit card required** — and access it via a permanent HTTPS URL from any phone, laptop, tablet, smart TV, or WebDAV client.

---

## ✨ Why ListCloud?

1. **100% Free & Zero Credit Card Required**:
   * Built natively for **Hugging Face Docker Spaces** (giving you **2 vCPUs + 16 GB RAM** for free without a credit card), **Render Free Web Services**, and **Koyeb Free Containers**.
2. **Never Lose Your Settings or Mounted Drives (4 Persistence Modes)**:
   * **External Free PostgreSQL (`DATABASE_URL`)**: Plug in a free 0.5 GB PostgreSQL database from [Neon.tech](https://neon.tech) or [Aiven](https://aiven.io) (no credit card). Even if your container rebuilds, all users, storage drives, and settings stay 100% intact.
   * **Hugging Face Private Dataset Sync (`SYNC_MODE=hf`)**: Automatically backs up your SQLite `data.db` and `config.json` to a private Hugging Face Dataset and restores it on boot.
   * **GitHub Private Repo Sync (`SYNC_MODE=github`)**: Automatically commits encrypted/archived SQLite state snapshots to a private GitHub repo.
   * **WebDAV Cloud Sync (`SYNC_MODE=webdav`)**: Automatically mirrors state to any WebDAV cloud drive.
3. **True 24/7 Uptime (No Cold-Start Sleeping)**:
   * Includes ready-to-use GitHub Action templates in [`workflows-templates/`](./workflows-templates) (`keepalive.yml`, `deploy-hf.yml`, `pages.yml`) that ping your cloud URL every 10 minutes + an internal self-pinging daemon (`scripts/keepalive.sh`).
4. **Supports Both Instant Official OpenList & Custom OpenList Builds**:
   * **Instant Mode**: Runs the latest official `OpenListTeam/OpenList` release out-of-the-box with automatic `ADMIN_PASSWORD` setup.
   * **Custom Mode**: Pass `CUSTOM_BINARY_URL` or `CUSTOM_DIST_URL` to run your own custom OpenList fork, custom drivers, or custom UI theme, plus built-in Aria2 offline download support (`ENABLE_ARIA2=true`).

---

## 🚀 1-Click Cloud Deployment (No Credit Card)

### Option A: Hugging Face Spaces (Recommended — 16 GB RAM, 2 vCPU, 100% Free)

1. Click **[Duplicate / Create Space on Hugging Face](https://huggingface.co/new-space)** and choose **Docker** as the SDK (or enable `workflows-templates/deploy-hf.yml` in `.github/workflows/`).
2. In your Space's **Settings → Variables and secrets**, set:
   * `ADMIN_USERNAME` = `admin`
   * `ADMIN_PASSWORD` = `your-strong-password`
   * `DATABASE_URL` = `postgresql://...` *(Optional: free Postgres from [Neon.tech](https://neon.tech) so data persists forever)*
   * Or set `SYNC_MODE=hf`, `HF_TOKEN=hf_...`, and `HF_DATASET_REPO=yourname/listcloud-backup` to auto-backup SQLite to a private HF dataset!
3. Once the Space says **Running**, open your permanent URL:
   ```text
   https://<your-hf-username>-<space-name>.hf.space
   ```

### Option B: Render + Neon.tech Free PostgreSQL

1. Create a free PostgreSQL database at [neon.tech](https://neon.tech) (no credit card required) and copy the `postgresql://...` connection string.
2. Click **[Deploy to Render](https://render.com/deploy?repo=https://github.com/Protegee1505/listcloud)**.
3. Paste your `DATABASE_URL` and set `ADMIN_PASSWORD`.
4. Render builds the container and gives you a live `https://listcloud-openlist.onrender.com` URL.

### Option C: Koyeb Free Cloud Container

1. Click **[Deploy to Koyeb](https://app.koyeb.com/deploy?type=git&repository=github.com/Protegee1505/listcloud&branch=main&name=listcloud)**.
2. Set `ADMIN_PASSWORD` and `DATABASE_URL` in the environment variables section and click **Deploy**.

---

## 🌐 Interactive Web Launchpad & Config Builder

This repository includes an interactive **Web Launchpad** inside [`web/`](./web/index.html) (ready for GitHub Pages or local browser use).
Use it to visually configure your instance, generate your `.env` / `config.json`, and launch your cloud OpenList in seconds.

---

## ⚙️ Environment Variables Reference

| Variable | Default | Description |
| :--- | :--- | :--- |
| `PORT` | `7860` | HTTP port bound by OpenList (`7860` on HF Spaces, `10000` on Render) |
| `ADMIN_USERNAME` | `admin` | Initial admin username |
| `ADMIN_PASSWORD` | *(auto/env)* | Sets the admin password automatically on boot |
| `CUSTOM_TITLE` | `ListCloud` | Custom site title |
| `DATABASE_URL` | *(empty)* | Free Postgres/MySQL URL (`postgresql://user:pass@host/db?sslmode=require`) |
| `SYNC_MODE` | `none` | Auto-sync mode when using SQLite: `none`, `hf`, `github`, or `webdav` |
| `HF_DATASET_REPO` | *(empty)* | Private HF Dataset (`username/repo`) when `SYNC_MODE=hf` |
| `HF_TOKEN` | *(empty)* | Hugging Face write token for `SYNC_MODE=hf` |
| `GITHUB_BACKUP_REPO` | *(empty)* | Private GitHub repo (`username/repo`) when `SYNC_MODE=github` |
| `GITHUB_TOKEN` | *(empty)* | GitHub PAT when `SYNC_MODE=github` |
| `WEBDAV_URL` | *(empty)* | Remote WebDAV folder URL when `SYNC_MODE=webdav` |
| `CUSTOM_BINARY_URL` | *(empty)* | URL to a custom OpenList binary or `.tar.gz` release |
| `CUSTOM_DIST_URL` | *(empty)* | URL to a custom OpenList frontend `dist.tar.gz` |
| `ENABLE_ARIA2` | `false` | Set to `true` to launch the built-in Aria2 RPC daemon on port `6800` |
| `KEEPALIVE_URL` | *(auto)* | External URL pinged periodically to keep free cloud routers awake |

---

## 🕒 Enable 24/7 Keep-Alive via GitHub Actions

To ensure your cloud instance stays warm 24/7:
1. Fork this repository on GitHub.
2. Go to **Settings → Secrets and variables → Actions → Variables**.
3. Create a repository variable named `INSTANCE_URLS` containing your cloud URL (e.g., `https://yourname-listcloud.hf.space`).
4. Enable the **24/7 Cloud Keep-Alive Pinger** workflow in the **Actions** tab.

---

## 📜 License & Attribution

* **ListCloud** is an independent community deployment toolkit and is not officially affiliated with the OpenList Team.
* Powered by **[OpenListTeam/OpenList](https://github.com/OpenListTeam/OpenList)** and distributed under the **[AGPL-3.0 License](./LICENSE)** in full compliance with OpenList's open-source governance.
