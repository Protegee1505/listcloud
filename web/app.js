(function () {
  const els = {
    cloudProvider: document.getElementById("cloudProvider"),
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
    enableKeepAlive: document.getElementById("enableKeepAlive"),
    generatedOutput: document.getElementById("generatedOutput"),
    copyCodeBtn: document.getElementById("copyCodeBtn"),
    tabBtns: document.querySelectorAll(".tab-btn"),
  };

  let activeTab = "env";

  function randomString(len) {
    const chars = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    let out = "";
    for (let i = 0; i < len; i++) {
      out += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return out;
  }

  function getPortForProvider(provider) {
    if (provider === "render") return 10000;
    return 7860;
  }

  function updateVisibility() {
    const isCustom = els.editionMode.value === "custom";
    els.customEditionFields.classList.toggle("hidden", !isCustom);

    const pMode = els.persistenceMode.value;
    els.postgresFields.classList.toggle("hidden", pMode !== "postgres");
    els.hfSyncFields.classList.toggle("hidden", pMode !== "hf");
    els.githubSyncFields.classList.toggle("hidden", pMode !== "github");
    els.webdavSyncFields.classList.toggle("hidden", pMode !== "webdav");
  }

  function buildEnvConfig() {
    const port = getPortForProvider(els.cloudProvider.value);
    const pMode = els.persistenceMode.value;
    const lines = [
      "# ListCloud — 100% Free 24/7 Cloud OpenList Environment",
      `PORT=${port}`,
      `ADMIN_USERNAME=${els.adminUser.value.trim() || "admin"}`,
      `ADMIN_PASSWORD=${els.adminPass.value.trim() || "listcloud123"}`,
      `CUSTOM_TITLE="${els.siteTitle.value.trim() || "My ListCloud"}"`,
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

    if (pMode === "postgres") {
      lines.push("SYNC_MODE=none");
      lines.push(
        `DATABASE_URL="${els.databaseUrl.value.trim() || "postgresql://user:pass@ep-free-db.neon.tech/neondb?sslmode=require"}"`
      );
    } else if (pMode === "hf") {
      lines.push("SYNC_MODE=hf");
      lines.push(`HF_DATASET_REPO="${els.hfDatasetRepo.value.trim() || "username/listcloud-backup"}"`);
      lines.push(`HF_TOKEN="${els.hfToken.value.trim() || "hf_your_write_token"}"`);
    } else if (pMode === "github") {
      lines.push("SYNC_MODE=github");
      lines.push(`GITHUB_BACKUP_REPO="${els.ghBackupRepo.value.trim() || "username/listcloud-state"}"`);
      lines.push(`GITHUB_TOKEN="${els.ghToken.value.trim() || "ghp_your_token"}"`);
    } else if (pMode === "webdav") {
      lines.push("SYNC_MODE=webdav");
      lines.push(`WEBDAV_URL="${els.webdavUrl.value.trim() || "https://dav.example.com/backup/"}"`);
      lines.push(`WEBDAV_USER="${els.webdavUser.value.trim() || "user"}"`);
      lines.push(`WEBDAV_PASSWORD="${els.webdavPass.value.trim() || "password"}"`);
    }

    if (els.enableKeepAlive.checked) {
      lines.push("KEEPALIVE_INTERVAL=480");
    }

    return lines.join("\n");
  }

  function buildJsonConfig() {
    const port = getPortForProvider(els.cloudProvider.value);
    const pMode = els.persistenceMode.value;
    const isPostgres = pMode === "postgres";

    const cfg = {
      force: false,
      site_url: "",
      cdn: "",
      jwt_secret: randomString(16),
      token_expires_in: 48,
      database: {
        type: isPostgres ? "postgres" : "sqlite3",
        host: isPostgres ? "ep-free-db.neon.tech" : "",
        port: isPostgres ? 5432 : 0,
        user: isPostgres ? "neondb_owner" : "",
        password: isPostgres ? "YOUR_DB_PASSWORD" : "",
        name: isPostgres ? "neondb" : "",
        db_file: "/opt/openlist/data/data.db",
        table_prefix: "x_",
        ssl_mode: isPostgres ? "require" : "",
      },
      scheme: {
        address: "0.0.0.0",
        http_port: port,
        https_port: -1,
        force_https: false,
      },
      temp_dir: "/opt/openlist/data/temp",
      bleve_dir: "/opt/openlist/data/bleve",
      MaxConcurrency: 64,
    };

    return JSON.stringify(cfg, null, 2);
  }

  function buildUrlPreview() {
    const provider = els.cloudProvider.value;
    const user = els.adminUser.value.trim() || "admin";
    const pass = els.adminPass.value.trim() || "listcloud123";

    let urlExample = "https://<your-hf-username>-listcloud.hf.space";
    if (provider === "render") {
      urlExample = "https://listcloud-openlist.onrender.com";
    } else if (provider === "koyeb") {
      urlExample = "https://listcloud-<your-org>.koyeb.app";
    }

    return [
      "=== Your Live 24/7 Cloud OpenList Endpoints ===",
      "",
      `Web Portal URL : ${urlExample}`,
      `WebDAV URL     : ${urlExample}/dav`,
      `Health Check   : ${urlExample}/ping`,
      "",
      "=== Initial Login Credentials ===",
      `Username       : ${user}`,
      `Password       : ${pass}`,
      "",
      "Access from anywhere: Desktop browser, iOS/Android, Infuse, VidHub, RaiDrive, rclone, or Kodi!",
    ].join("\n");
  }

  function renderOutput() {
    updateVisibility();
    if (activeTab === "env") {
      els.generatedOutput.textContent = buildEnvConfig();
    } else if (activeTab === "config") {
      els.generatedOutput.textContent = buildJsonConfig();
    } else {
      els.generatedOutput.textContent = buildUrlPreview();
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
      const orig = els.copyCodeBtn.textContent;
      els.copyCodeBtn.textContent = "Copied!";
      setTimeout(() => {
        els.copyCodeBtn.textContent = orig;
      }, 1500);
    });
  });

  document.querySelectorAll("input, select").forEach((input) => {
    input.addEventListener("input", renderOutput);
    input.addEventListener("change", renderOutput);
  });

  // Initialize default password
  els.adminPass.value = "LC_" + randomString(10);
  renderOutput();
})();
