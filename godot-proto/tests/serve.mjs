// Мини-сервер для проверки: отдаёт папку (build/ или собранный сайт) с предсжатым gzip (как CDN/nginx gzip_static).
// Как GitHub Pages: /папка/ → /папка/index.html, /папка без слэша → 301 на /папка/.
import http from "http"; import fs from "fs"; import path from "path"; import zlib from "zlib";
const root = path.resolve(process.argv[2] || "build"), port = +(process.argv[3] || 8790);
const types = { ".html": "text/html; charset=utf-8", ".js": "application/javascript", ".wasm": "application/wasm",
  ".pck": "application/octet-stream", ".png": "image/png", ".webp": "image/webp", ".json": "application/json",
  ".css": "text/css", ".woff2": "font/woff2", ".txt": "text/plain; charset=utf-8" };
const packed = new Set([".png", ".webp", ".woff2"]);   // уже сжатые форматы — без gzip
const cache = {};
http.createServer((req, res) => {
  const [rawPath, qs] = req.url.split("?");
  let p = decodeURIComponent(rawPath);
  let f = path.join(root, p);
  if (!f.startsWith(root)) { res.writeHead(404); return res.end(); }
  if (fs.existsSync(f) && fs.statSync(f).isDirectory()) {
    if (!p.endsWith("/")) { res.writeHead(301, { Location: rawPath + "/" + (qs !== undefined ? "?" + qs : "") }); return res.end(); }
    f = path.join(f, "index.html");
  }
  if (!fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  const ext = path.extname(f); const gz = /gzip/.test(req.headers["accept-encoding"] || "") && !packed.has(ext);
  const headers = { "Content-Type": types[ext] || "application/octet-stream" };
  if (!process.env.NOCOI) { headers["Cross-Origin-Opener-Policy"] = "same-origin"; headers["Cross-Origin-Embedder-Policy"] = "require-corp"; }
  let body = fs.readFileSync(f);
  if (gz) { body = cache[f] ||= zlib.gzipSync(body, { level: 9 }); headers["Content-Encoding"] = "gzip"; }
  headers["Content-Length"] = body.length; res.writeHead(200, headers); res.end(body);
}).listen(port, "127.0.0.1", () => console.log("serving", root, port));
