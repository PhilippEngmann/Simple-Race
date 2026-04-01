import http.server
import socketserver

PORT = 8000


class CrossOriginIsolationHandler(http.server.SimpleHTTPRequestHandler):
    """
    Handler that adds headers required for Cross-Origin Isolation
    and SharedArrayBuffer support.
    """

    def end_headers(self):
        # Required for Cross-Origin Isolation
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")

        # Optional: Disable caching to ensure changes are reflected immediately
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")

        super().end_headers()


if __name__ == "__main__":
    # Allow address reuse to avoid "Address already in use" errors on restart
    socketserver.TCPServer.allow_reuse_address = True

    with socketserver.TCPServer(("", PORT), CrossOriginIsolationHandler) as httpd:
        print(f"Serving at http://localhost:{PORT}")
        print("Headers enabled: COOP (same-origin) and COEP (require-corp)")
        print("Press Ctrl+C to stop the server.")

        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down server...")
            httpd.server_close()
