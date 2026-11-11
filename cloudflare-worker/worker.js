/**
 * ListCloud — optional Cloudflare Worker reverse proxy
 *
 * Gives your OpenList instance:
 *  - your own domain (or a clean *.workers.dev URL)
 *  - edge buffering for proxied downloads
 *  - CORS handling
 *
 * Set UPSTREAM_URL to your Render URL, e.g. https://listcloud.onrender.com
 * (or set it as a Worker variable in the Cloudflare dashboard).
 */

const DEFAULT_UPSTREAM = "https://YOUR-SERVICE.onrender.com";

export default {
  async fetch(request, env) {
    const upstreamBase = (env.UPSTREAM_URL || DEFAULT_UPSTREAM).replace(/\/+$/, "");
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS, PROPFIND, MKCOL, MOVE, COPY",
          "Access-Control-Allow-Headers": "*",
          "Access-Control-Max-Age": "86400",
        },
      });
    }

    const target = new URL(url.pathname + url.search, upstreamBase);
    const headers = new Headers(request.headers);
    headers.set("Host", target.host);
    headers.set("X-Forwarded-Host", url.host);
    headers.set("X-Forwarded-Proto", url.protocol.replace(":", ""));

    const upstream = await fetch(
      new Request(target.toString(), {
        method: request.method,
        headers,
        body: ["GET", "HEAD"].includes(request.method) ? null : request.body,
        redirect: "manual",
      })
    );

    const resHeaders = new Headers(upstream.headers);
    resHeaders.set("Access-Control-Allow-Origin", "*");

    return new Response(upstream.body, {
      status: upstream.status,
      statusText: upstream.statusText,
      headers: resHeaders,
    });
  },
};
