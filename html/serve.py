#!/usr/bin/env python3
import http.server
import socketserver
from functools import partial

class CORSRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        super().end_headers()

PORT = 8000

with socketserver.TCPServer(("", PORT), CORSRequestHandler) as httpd:
    print(f"Server running at http://localhost:{PORT}/")
    print("Press Ctrl+C to stop")
    httpd.serve_forever()