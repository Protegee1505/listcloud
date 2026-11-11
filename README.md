# ☁️ ListCloud — run OpenList on the cloud for free, without a credit card

[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL%203.0-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Powered by OpenList](https://img.shields.io/badge/Powered%20by-OpenList-00b4d8)](https://github.com/OpenListTeam/OpenList)
[![Deploy to Render](https://img.shields.io/badge/%E2%9A%A1%20Deploy%20to-Render%20(Free)-46E3B7)](https://render.com/deploy?repo=https://github.com/Protegee1505/listcloud)

ListCloud deploys a **standard or custom [OpenList](https://github.com/OpenListTeam/OpenList)** instance to the cloud and gives you a permanent HTTPS URL you can open from any phone, laptop, tablet, TV or WebDAV client.

* **$0 forever, no credit card**
* **Persistent data** via a free PostgreSQL database (Neon) or automatic SQLite snapshots
* **Stays awake** with a free 5-minute keep-alive ping
* **Standard or custom builds** (custom binary, custom UI, optional Aria2)

---

## ⚠️ Read this first: the free-hosting landscape changed in 2026

Many older tutorials still say "deploy OpenList to Hugging Face Spaces or Koyeb for free". That is no longer true:

| Platform | Status (November 2026) |
| :--- | :--- |
| **Hugging Face Docker Spaces** | Docker and Gradio Spaces **require a paid plan** (PRO/Team). Only Static Spaces and limited ZeroGPU Gradio Spaces are free. |
| **Koyeb** | Free Starter plan is **closed to new accounts**; a credit card with a $29 hold is required, and new accounts start on the $29/month Pro plan. |
| **Render Free** | **Still free, no credit card.** 512 MB RAM, 0.1 CPU, 750 instance hours/month. Spins down after 15 minutes idle (keep-alive fixes this). |
| **Neon Free Postgres** | **Free forever, no credit card.** 1 GB storage, 100 compute-hours/month, scales to zero after 5 minutes idle. |

So ListCloud targets **Render Free + Neon Free Postgres** as the primary path. The Docker image still runs anywhere Docker runs, including a Hugging Face account that already has grandfathered free access.

---

## 🚀 Quick start (about 10 minutes)

### Step 1 — Create a free PostgreSQL database (Neon)

Render's free filesystem is **ephemeral**: it is wiped on every restart, redeploy and spin-down. A database is what keeps your users, storage mounts and settings.

1. Go to **[neon.com](https://neon.com)** and sign up with GitHub or email (no credit card).
2. Click **New Project**, pick any region close to you, and create it.
3. On the project dashboard, click **Connect** and copy the **connection string**. It looks like:

   ```text
   postgresql://user:password@ep-something.region.aws.neon.tech/neondb?sslmode=require
   ```

   Use the **direct** connection string (leave "Pooled connection" unchecked). Keep this string — it is your `DATABASE_URL`.

> Prefer not to create a database? You can skip this and use `SYNC_MODE=hf` later, which snapshots SQLite to a private Hugging Face **Dataset** (Datasets are still free). You will lose changes made since the last snapshot whenever the container stops.

### Step 2 — Deploy to Render

1. Open **[render.com/deploy?repo=https://github.com/Protegee1505/listcloud](https://render.com/deploy?repo=https://github.com/Protegee1505/listcloud)**.
2. Sign in with GitHub when asked.
3. Render reads [`render.yaml`](./render.yaml) and shows a Blueprint named **listcloud**. Keep the **Free** plan.
4. Fill in the environment variables:
   * **`DATABASE_URL`** → paste the Neon connection string from Step 1.
   * **`ADMIN_PASSWORD`** → enter a password of 4+ characters, **or leave it empty** to get OpenList's browser setup wizard on first visit.
   * `ADMIN_USERNAME` is `admin` and only matters when `ADMIN_PASSWORD` is set.
   * `CUSTOM_TITLE` → your site name.
5. Click **Apply** / **Deploy** and wait for the build (typically 3–6 minutes).

> Render might ask you to verify your account by email, but does not require a card for Free web services. If you have no payment method on file, Render suspends services when you hit a limit instead of billing you.

### Step 3 — Open your instance

1. In the Render dashboard, open the **listcloud** service and copy its URL, for example:

   ```text
   https://listcloud-ab12.onrender.com
   ```

2. Open it in a browser.
   * If you set `ADMIN_PASSWORD`, log in as `admin` with that password.
   * If you left it empty, complete the setup wizard: choose your username, password and site title.

The first request after a spin-down can take ~1 minute while Render boots the container.

### Step 4 — Add your storage

1. Log in, open the menu (bottom-left avatar), then **Manage**.
2. Go to **Storage → Add storage**.
3. Pick a provider (OneDrive, Google Drive, S3, WebDAV, FTP, 115, PikPak, and 40+ more), fill in the credentials and **Save**.
4. Go back to **Home** and open the mounted storage.

### Step 5 — Keep it online 24/7 (free)

Render spins a Free service down after **15 minutes without traffic**. A ping every 5 minutes keeps it warm and still fits inside the **750 free instance hours/month** (a 31-day month is 744 hours).

**Option A — GitHub Actions (free):**

1. **Fork** this repository on GitHub.
2. In your fork: **Settings → Secrets and variables → Actions → Variables → New repository variable**.
3. Name `INSTANCE_URLS`, value `https://your-service.onrender.com`.
4. Open the **Actions** tab and enable **Keep the free instance awake** (it runs every 5 minutes).

**Option B — cron-job.org (also free):** create a job that GETs `https://your-service.onrender.com/ping` every 5 minutes.

> GitHub sometimes delays scheduled runs. If a run slips past 15 minutes you may see one cold start; a second scheduler makes this rarer.

### Step 6 — Use it from anywhere

| What | URL |
| :--- | :--- |
| Web UI | `https://your-service.onrender.com` |
| WebDAV | `https://your-service.onrender.com/dav` |
| Health check | `https://your-service.onrender.com/ping` |

Log in with your OpenList username/password. For WebDAV in apps like Infuse, RaiDrive, rclone or Kodi, use the same URL and credentials (or an app password from **Manage → Users**).

---

## 🧩 Optional features

### Automatic SQLite backups instead of a database

If you don't use `DATABASE_URL`, set one of these on Render and ListCloud snapshots `data.db` + `config.json`:

| `SYNC_MODE` | What it needs | Notes |
| :--- | :--- | :--- |
| `hf` | `HF_TOKEN`, `HF_DATASET_REPO` (e.g. `you/listcloud-backup`) | Private Hugging Face **Dataset**. Create a write token at huggingface.co/settings/tokens. |
| `github` | `GITHUB_TOKEN`, `GITHUB_BACKUP_REPO` (e.g. `you/listcloud-state`) | Private GitHub repo, fine-grained token with Contents write. |
| `webdav` | `WEBDAV_URL`, `WEBDAV_USER`, `WEBDAV_PASSWORD` | Any WebDAV storage. |

Snapshots run every `SYNC_INTERVAL` seconds (default 300) when the database changes, on boot restore, and on shutdown. A crash can still lose the last few minutes of changes — a real database is safer.

### Custom OpenList build

| Variable | Purpose |
| :--- | :--- |
| `CUSTOM_BINARY_URL` | URL of a custom `openlist` binary, or a `.tar.gz` whose root contains `openlist`. Replaces the bundled binary at boot. |
| `CUSTOM_DIST_URL` | URL of a custom frontend `dist.tar.gz` (with `index.html` at its root). Served as the UI. |
| `ENABLE_ARIA2` | `true` to start Aria2 RPC on port 6800. Needs RAM; leave `false` on the 512 MB free instance. |
| `ENABLE_FFMPEG` | Build-time arg only: `docker build --build-arg INSTALL_FFMPEG=true`. Not available on Render's prebuilt image. |

### Custom domain (optional, free)

Deploy [`cloudflare-worker/worker.js`](./cloudflare-worker/worker.js) as a Cloudflare Worker (Workers' free plan needs no card), set `UPSTREAM_URL` to your Render URL, then attach a domain to the Worker.

### Publish the config builder

The interactive builder in [`docs/`](./docs) is static. Publish it with **Settings → Pages → Deploy from a branch → `main` / `/docs`**, or run the included [`workflows-templates/pages.yml`](./workflows-templates/pages.yml) as a workflow.

---

## 💻 Run locally

```bash
git clone https://github.com/Protegee1505/listcloud.git
cd listcloud
docker compose up --build
```

Open `http://localhost:10000`. Local runs use SQLite in `./data`, which is fine because the folder is on your machine.

Without Docker:

```bash
curl -fsSL https://github.com/OpenListTeam/OpenList/releases/latest/download/openlist-linux-musl-amd64.tar.gz | tar -xz
PORT=10000 ADMIN_PASSWORD=change-me ./openlist server --data ./data --no-prefix
```

---

## ⚙️ Environment variables

| Variable | Default | Description |
| :--- | :--- | :--- |
| `PORT` | `10000` | HTTP port. Render sets this automatically. |
| `ADMIN_USERNAME` | `admin` | Only used when `ADMIN_PASSWORD` is set (pre-provisioning). |
| `ADMIN_PASSWORD` | *(empty)* | 4+ chars. Empty means "show the setup wizard". Applied only on first setup, never afterwards. |
| `CUSTOM_TITLE` | *(empty)* | Site title applied during pre-provisioning. |
| `DATABASE_URL` | *(empty)* | `postgresql://...`. Strongly recommended for persistence. |
| `JWT_SECRET` | random | Keeps sessions valid across restarts. Set it. |
| `SYNC_MODE` | `none` | `none`, `hf`, `github`, `webdav` (SQLite only). |
| `SYNC_INTERVAL` | `300` | Seconds between snapshot checks. |
| `HF_TOKEN`, `HF_DATASET_REPO` | *(empty)* | For `SYNC_MODE=hf`. |
| `GITHUB_TOKEN`, `GITHUB_BACKUP_REPO` | *(empty)* | For `SYNC_MODE=github`. |
| `WEBDAV_URL`, `WEBDAV_USER`, `WEBDAV_PASSWORD` | *(empty)* | For `SYNC_MODE=webdav`. |
| `ENABLE_ARIA2` | `false` | Start Aria2 RPC. |
| `CUSTOM_BINARY_URL`, `CUSTOM_DIST_URL` | *(empty)* | Custom OpenList build. |
| `KEEPALIVE_INTERVAL` | `600` | Internal self-ping interval in seconds. |
| `KEEPALIVE_URL` | *(auto)* | Overrides the URL the internal keep-alive pings. |

---

## 📉 Honest limits of the free tier

* **512 MB RAM / 0.1 CPU** on Render Free. OpenList runs fine; Aria2 and heavy transcoding do not.
* **15-minute spin-down.** The keep-alive handles it; the first request after a long gap takes ~1 minute.
* **750 instance hours/month** per workspace. One always-on service uses ~744; a second free service will compete for the same hours.
* **Ephemeral disk.** Without `DATABASE_URL` or `SYNC_MODE`, your mounts and settings disappear on restart.
* **Limited outbound bandwidth** on the free workspace (check your workspace's included usage in the Render dashboard). OpenList normally redirects downloads straight to the cloud provider (HTTP 302), so most download traffic never touches Render. Proxied previews, WebDAV transfers and `?proxy` downloads do count.
* **Neon Free** gives 1 GB storage and 100 compute-hours/month; if you exhaust compute, the database pauses until the next month. Keep the project small.
* Free tiers are for hobby/testing. No uptime guarantee, and providers can restart or change limits at any time.

---

## 🩺 Troubleshooting

| Symptom | Fix |
| :--- | :--- |
| "Application failed to respond" on first open | Render is cold-starting. Wait ~60 seconds and reload. |
| Setup wizard keeps appearing | The container is not reaching `DATABASE_URL`. Check Render logs for `Using external PostgreSQL database`; verify the Neon string includes `?sslmode=require`. |
| Login fails after you set `ADMIN_PASSWORD` | The password only applies to first setup. If the instance was already initialized, reset it in **Manage → Users**, or wipe the Neon database and redeploy. |
| Settings vanish after a deploy | No persistent database. Add `DATABASE_URL` (or `SYNC_MODE`). |
| Build fails downloading OpenList | The GitHub release URL changed or rate-limited. Redeploy; pin `OPENLIST_VERSION` with a build arg if needed. |
| 502 after inactivity | Keep-alive is not running. Check the Actions run / cron-job. |
| Forgot admin password | On a fresh database, delete and recreate the Neon project, then redeploy. OpenList has no email reset. |

---

## 🗂 Repository layout

```text
listcloud/
├── Dockerfile                  # OpenList + sync/keepalive runtime
├── render.yaml                 # Render Blueprint (free plan)
├── docker-compose.yml          # Local / self-hosted
├── scripts/
│   ├── entrypoint.sh           # Port, DB, admin provisioning, custom builds
│   ├── db-sync.sh              # SQLite snapshots to HF / GitHub / WebDAV
│   └── keepalive.sh            # Internal self-ping
├── cloudflare-worker/worker.js # Optional custom-domain proxy
├── docs/                       # Static config builder (GitHub Pages)
└── workflows-templates/        # Keep-alive and Pages workflows
```

---

## 📜 License

AGPL-3.0, matching upstream OpenList. ListCloud is an independent deployment project and is not affiliated with the OpenList Team. See [LICENSE](./LICENSE).
