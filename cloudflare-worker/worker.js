/**
 * ListCloud — Free Cloudflare Worker Reverse Proxy & Download Accelerator
 *
 * Gives your free Hugging Face Space / Render / Koyeb OpenList instance:
 *  1. Your own custom domain or clean *.workers.dev URL
 *  2. Edge stream acceleration for large cloud drive downloads
 *  3. Automatic CORS headers & wake-up ping forwarding
 */

const DEFAULT_UPSTREAM = "https://YOUR-USERNAME-listcloud.hf.space";

export default {
  async fetch(request, env, ctx) {
    const upstreamBase = (env.UPSTREAM_URL || DEFAULT_UPSTREAM).replace(/\/+$/, "");
    const url = new URL(request.url);

    // Handle CORS preflight requests at the edge
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

    const targetUrl = new URL(url.pathname + url.search, upstreamBase);
    const headers = new Headers(request.headers);
    headers.set("Host", targetUrl.host);
    headers.set("X-Forwarded-Host", url.host);
    headers.set("X-Forwarded-Proto", url.protocol.replace(":", ""));

    const upstreamReq = new Request(targetUrl.toString(), {
      method: request.method,
      headers,
      body: ["GET", "HEAD"].includes(request.method) ? null : request.body,
      redirect: "manual",
    });

    const response = await fetch(upstreamReq);
    const resHeaders = new Headers(response.headers);
    resHeaders.set("Access-Control-Allow-Origin", "*");

    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers: resHeaders,
    });
  },
};
