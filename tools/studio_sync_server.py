"""Serve src/ to Roblox Studio for tools/studio_sync.luau (Rojo is not installed here).

Run from the repo root:  python tools/studio_sync_server.py
Listens on 127.0.0.1:34873 only. GET /manifest returns every .luau file with
its Studio path (default.project.json mapping, Rojo naming: *.server.luau →
Script, *.client.luau → LocalScript, else ModuleScript). GET /file/<rel>
returns one file. Read-only; nothing is written.
"""

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src")
MOUNTS = {
    "shared": ["ReplicatedStorage", "Shared"],
    "server": ["ServerScriptService", "Server"],
    "client": ["StarterPlayer", "StarterPlayerScripts", "Client"],
}
PORT = 34873


def manifest():
    entries = []
    for mount, studio in MOUNTS.items():
        base = os.path.join(ROOT, mount)
        for folder, _, files in os.walk(base):
            for name in sorted(files):
                if not name.endswith(".luau"):
                    continue
                rel = os.path.relpath(os.path.join(folder, name), ROOT).replace(os.sep, "/")
                parts = rel.split("/")[1:-1]
                stem, cls = name[:-5], "ModuleScript"
                if stem.endswith(".server"):
                    stem, cls = stem[:-7], "Script"
                elif stem.endswith(".client"):
                    stem, cls = stem[:-7], "LocalScript"
                entries.append({"path": studio + parts + [stem], "class": cls, "file": rel})
    return entries


class Handler(BaseHTTPRequestHandler):
    def send(self, code, body, kind="text/plain; charset=utf-8"):
        data = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/manifest":
            return self.send(200, json.dumps(manifest()), "application/json")
        if self.path.startswith("/file/"):
            rel = unquote(self.path[len("/file/"):])
            full = os.path.realpath(os.path.join(ROOT, rel))
            # Only files under src/ and only .luau.
            if not full.startswith(os.path.realpath(ROOT)) or not full.endswith(".luau") or not os.path.isfile(full):
                return self.send(404, "not found")
            with open(full, encoding="utf-8") as f:
                return self.send(200, f.read().replace("\r\n", "\n"))
        return self.send(404, "not found")

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    print(f"studio sync server on http://127.0.0.1:{PORT}", flush=True)
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
