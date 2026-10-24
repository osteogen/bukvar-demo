// Мини-сервер: отдаёт build/ с предсжатым gzip (как сделал бы CDN/nginx gzip_static).
import http from "http"; import fs from "fs"; import path from "path"; import zlib from "zlib";
const root = path.resolve(process.argv[2] || "build"), port = +(process.argv[3] || 8790);
const types = { ".html": "text/html", ".js": "application/javascript", ".wasm": "application/wasm", ".pck": "application/octet-stream", ".png": "image/png", ".json": "application/json" };
const cache = {};
http.createServer((req, res) => {
  let p = decodeURIComponent(req.url.split("?")[0]); if (p === "/") p = "/index.html";
  const f = path.join(root, p); if (!f.startsWith(root) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  const ext = path.extname(f); const gz = /gzip/.test(req.headers["accept-encoding"] || "") && ext !== ".png";
  const headers = { "Content-Type": types[ext] || "application/octet-stream" };
  if (!process.env.NOCOI) { headers["Cross-Origin-Opener-Policy"] = "same-origin"; headers["Cross-Origin-Embedder-Policy"] = "require-corp"; }
  let body = fs.readFileSync(f);
  if (gz) { body = cache[f] ||= zlib.gzipSync(body, { level: 9 }); headers["Content-Encoding"] = "gzip"; }
  headers["Content-Length"] = body.length; res.writeHead(200, headers); res.end(body);
}).listen(port, "127.0.0.1", () => console.log("serving", root, port));
