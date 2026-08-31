const http = require("http");
const fs = require("fs");
const path = require("path");

const root = __dirname;
const port = 4173;

const mime = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".svg": "image/svg+xml"
};

http.createServer((req, res) => {
  // emula a rota /api/preorder localmente (a vercel resolve isso sozinha
  // em produção, isto é só pra testar o fluxo completo no navegador aqui).
  if (req.url.split("?")[0] === "/api/preorder" && req.method === "POST") {
    let chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      let body = {};
      try { body = JSON.parse(Buffer.concat(chunks).toString() || "{}"); } catch (e) {}
      const handler = require("./api/preorder.js");
      const fakeRes = {
        status(code) { this._status = code; return this; },
        json(obj) {
          res.writeHead(this._status || 200, { "Content-Type": "application/json" });
          res.end(JSON.stringify(obj));
        }
      };
      handler({ method: "POST", headers: req.headers, socket: req.socket, body }, fakeRes)
        .catch((err) => {
          res.writeHead(500, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ ok: false, message: String(err) }));
        });
    });
    return;
  }

  let filePath = path.join(root, decodeURIComponent(req.url.split("?")[0]));
  if (filePath.endsWith("/")) filePath = path.join(filePath, "index.html");
  if (!path.extname(filePath)) filePath = path.join(filePath, "index.html");

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end("not found");
      return;
    }
    res.writeHead(200, { "Content-Type": mime[path.extname(filePath)] || "application/octet-stream" });
    res.end(data);
  });
}).listen(port, () => console.log(`serving ${root} on http://localhost:${port}`));
