# Build context: the michaels-cal repo root (see build instructions in README.md)
FROM docker.io/library/node:22-alpine

ENV NODE_ENV=production \
    REFRESH_INTERVAL=21600 \
    PORT=8080

RUN corepack enable

WORKDIR /app

COPY package.json pnpm-lock.yaml ./
# tsx is a devDependency but is required at runtime, so install everything
# build scripts (biome, esbuild postinstall) are not needed; binaries ship as optional deps
RUN pnpm install --frozen-lockfile --config.strict-dep-builds=false

COPY tsconfig.json ./
COPY src ./src

COPY --chmod=644 <<'SERVER' /usr/local/bin/serve.mjs
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";

// Serves exactly one file; everything else is a 404.
createServer(async (req, res) => {
  const path = new URL(req.url, "http://x").pathname;
  if (path !== "/michaels-cal.ics" || !["GET", "HEAD"].includes(req.method)) {
    res.writeHead(404).end();
    return;
  }
  try {
    const body = await readFile("/srv/www/michaels-cal.ics");
    res.writeHead(200, {
      "Content-Type": "text/calendar; charset=utf-8",
      "Content-Length": body.length,
    });
    res.end(req.method === "HEAD" ? undefined : body);
  } catch {
    res.writeHead(503, { "Retry-After": "30" }).end("calendar not generated yet\n");
  }
}).listen(Number(process.env.PORT ?? 8080));
SERVER

COPY --chmod=755 <<'SCRIPT' /usr/local/bin/entrypoint.sh
#!/bin/sh
# Regenerates the calendar every REFRESH_INTERVAL seconds and serves only the
# finished .ics file. The script's other output in ./out (login.html,
# schedule.html, *.json) contains personal data and is never served.
WWW=/srv/www
mkdir -p "$WWW" /app/out

refresh_loop() {
  while true; do
    if node --import=tsx src/index.ts; then
      cp -f out/michaels-cal.ics "$WWW/michaels-cal.ics.tmp" \
        && mv -f "$WWW/michaels-cal.ics.tmp" "$WWW/michaels-cal.ics"
    else
      echo "refresh failed; keeping previous calendar (if any)" >&2
    fi
    sleep "$REFRESH_INTERVAL"
  done
}

refresh_loop &
exec node /usr/local/bin/serve.mjs
SCRIPT

# Writable locations: /app/out, /srv/www and /tmp (tsx cache) (mount emptyDirs here when the
# root filesystem is read-only). The node user (uid 1000) owns them.
RUN mkdir -p /app/out /srv/www && chown -R node:node /app/out /srv/www
USER 1000

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
