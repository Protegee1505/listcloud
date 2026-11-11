(function () {
  const els = {
    adminUser: document.getElementById("adminUser"),
    adminPass: document.getElementById("adminPass"),
    genPassBtn: document.getElementById("genPassBtn"),
    siteTitle: document.getElementById("siteTitle"),
    editionMode: document.getElementById("editionMode"),
    customEditionFields: document.getElementById("customEditionFields"),
    customBinaryUrl: document.getElementById("customBinaryUrl"),
    customDistUrl: document.getElementById("customDistUrl"),
    persistenceMode: document.getElementById("persistenceMode"),
    postgresFields: document.getElementById("postgresFields"),
    hfSyncFields: document.getElementById("hfSyncFields"),
    githubSyncFields: document.getElementById("githubSyncFields"),
    webdavSyncFields: document.getElementById("webdavSyncFields"),
    databaseUrl: document.getElementById("databaseUrl"),
    hfDatasetRepo: document.getElementById("hfDatasetRepo"),
    hfToken: document.getElementById("hfToken"),
    ghBackupRepo: document.getElementById("ghBackupRepo"),
    ghToken: document.getElementById("ghToken"),
    webdavUrl: document.getElementById("webdavUrl"),
    webdavUser: document.getElementById("webdavUser"),
    webdavPass: document.getElementById("webdavPass"),
    enableAria2: document.getElementById("enableAria2"),
    generatedOutput: document.getElementById("generatedOutput"),
    copyCodeBtn: document.getElementById("copyCodeBtn"),
    tabBtns: document.querySelectorAll(".tab-btn"),
  };

  let activeTab = "env";
  const jwtSecret = randomString(32);

  function randomString(len) {
    const chars = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    let out = "";
    for (let i = 0; i < len; i++) {
      out += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return out;
  }

  function updateVisibility() {
    const isCustom = els.editionMode.value === "custom";
    els.customEditionFields.classList.toggle("hidden", !isCustom);

    const mode = els.persistenceMode.value;
    els.postgresFields.classList.toggle("hidden", mode !== "postgres");
    els.hfSyncFields.classList.toggle("hidden", mode !== "hf");
    els.githubSyncFields.classList.toggle("hidden", mode !== "github");
    els.webdavSyncFields.classList.toggle("hidden", mode !== "webdav");
  }

  function buildEnvConfig() {
    const mode = els.persistenceMode.value;
    const lines = [
      "# ListCloud on Render (Free) — paste these into the Blueprint",
      "PORT=10000",
      `ADMIN_USERNAME=${els.adminUser.value.trim() || "admin"}`,
      `ADMIN_PASSWORD=${els.adminPass.value.trim()}`,
      `CUSTOM_TITLE="${els.siteTitle.value.trim()}"`,
      `JWT_SECRET=${jwtSecret}`,
      `ENABLE_ARIA2=${els.enableAria2.checked ? "true" : "false"}`,
    ];

    if (els.editionMode.value === "custom") {
      if (els.customBinaryUrl.value.trim()) {
        lines.push(`CUSTOM_BINARY_URL="${els.customBinaryUrl.value.trim()}"`);
      }
      if (els.customDistUrl.value.trim()) {
        lines.push(`CUSTOM_DIST_URL="${els.customDistUrl.value.trim()}"`);
      }
    }

    if (mode === "postgres") {
      lines.push("SYNC_MODE=none");
      lines.push(
        `DATABASE_URL="${els.databaseUrl.value.trim() || "postgresql://user:pass@ep-xxx.region.aws.neon.tech/neondb?sslmode=require"}"`
      );
    } else if (mode === "hf") {
      lines.push("SYNC_MODE=hf");
      lines.push(`HF_DATASET_REPO="${els.hfDatasetRepo.value.trim() || "username/listcloud-backup"}"`);
      lines.push(`HF_TOKEN="${els.hfToken.value.trim() || "hf_your_write_token"}"`);
    } else if (mode === "github") {
      lines.push("SYNC_MODE=github");
      lines.push(`GITHUB_BACKUP_REPO="${els.ghBackupRepo.value.trim() || "username/listcloud-state"}"`);
      lines.push(`GITHUB_TOKEN="${els.ghToken.value.trim() || "github_pat_xxx"}"`);
    } else {
      lines.push("SYNC_MODE=webdav");
      lines.push(`WEBDAV_URL="${els.webdavUrl.value.trim() || "https://dav.example.com/backup/"}"`);
      lines.push(`WEBDAV_USER="${els.webdavUser.value.trim() || "user"}"`);
      lines.push(`WEBDAV_PASSWORD="${els.webdavPass.value.trim() || "password"}"`);
    }

    return lines.join("\n");
  }

  function buildUrlPreview() {
    const user = els.adminUser.value.trim() || "admin";
    const pass = els.adminPass.value.trim();
    return [
      "=== Your instance (copy the real URL from the Render dashboard) ===",
      "",
      "Web UI   : https://your-service.onrender.com",
      "WebDAV   : https://your-service.onrender.com/dav",
      "Health   : https://your-service.onrender.com/ping",
      "",
      "=== First login ===",
      pass
        ? `Username : ${user}\nPassword : ${pass}`
        : "No password was pre-set: the first visit opens OpenList's setup wizard.",
      "",
      "The first request after a spin-down takes about a minute.",
    ].join("\n");
  }

  function buildChecklist() {
    return [
      "1. Create a free Neon project at neon.com (no card) and copy the",
      "   postgresql://... connection string.",
      "",
      "2. Open https://render.com/deploy?repo=https://github.com/Protegee1505/listcloud",
      "   sign in with GitHub, keep the Free plan.",
      "",
      "3. Paste DATABASE_URL, ADMIN_PASSWORD and CUSTOM_TITLE from the",
      "   Environment tab, then click Apply.",
      "",
      "4. Wait for the build (3-6 min) and open the *.onrender.com URL.",
      "   Log in, or complete the setup wizard if no password was set.",
      "",
      "5. Add storage: Manage -> Storage -> Add storage -> choose provider.",
      "",
      "6. Keep it awake: fork the repo, then Settings -> Secrets and",
      "   variables -> Actions -> Variables -> INSTANCE_URLS = your URL.",
      "   Enable the 'Keep the free instance awake' workflow.",
      "",
      "Optional: cron-job.org pinging /ping every 5 minutes as a backup.",
    ].join("\n");
  }

  function renderOutput() {
    updateVisibility();
    if (activeTab === "env") {
      els.generatedOutput.textContent = buildEnvConfig();
    } else if (activeTab === "url") {
      els.generatedOutput.textContent = buildUrlPreview();
    } else {
      els.generatedOutput.textContent = buildChecklist();
    }
  }

  els.genPassBtn.addEventListener("click", () => {
    els.adminPass.value = "LC_" + randomString(12);
    renderOutput();
  });

  els.tabBtns.forEach((btn) => {
    btn.addEventListener("click", () => {
      els.tabBtns.forEach((b) => b.classList.remove("active"));
      btn.classList.add("active");
      activeTab = btn.dataset.tab;
      renderOutput();
    });
  });

  els.copyCodeBtn.addEventListener("click", () => {
    navigator.clipboard.writeText(els.generatedOutput.textContent).then(() => {
      const original = els.copyCodeBtn.textContent;
      els.copyCodeBtn.textContent = "Copied";
      setTimeout(() => {
        els.copyCodeBtn.textContent = original;
      }, 1500);
    });
  });

  document.querySelectorAll("input, select").forEach((input) => {
    input.addEventListener("input", renderOutput);
    input.addEventListener("change", renderOutput);
  });

  renderOutput();
})();
