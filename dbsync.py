"""DBSync server: hands the Discovery Bay scripts to the DBSync Studio plugin.

Run it with dbsync.bat and leave the window open. It only listens on 127.0.0.1:34999.
  /stamp       -> when each script file last changed (JSON), polled by the plugin every second
  /<filename>  -> that script's source, fetched only after it changed
"""
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
FILES = [
    "DiscoveryBayData.luau",
    "DiscoveryBayBuild.server.luau",
    "DiscoveryBayShop.server.luau",
    "DiscoveryBayClient.client.luau",
]
PORT = 34999


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        name = self.path.split("?")[0].lstrip("/")
        if name == "stamp":
            body = json.dumps({f: os.path.getmtime(os.path.join(HERE, f)) for f in FILES}).encode()
        elif name in FILES:
            with open(os.path.join(HERE, name), "rb") as fh:
                body = fh.read()
            print("sent " + name + " to Studio")
        else:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass  # the plugin polls every second; keep the window quiet


if __name__ == "__main__":
    print("DBSync server running on http://127.0.0.1:%d - leave this window open while you work" % PORT)
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
