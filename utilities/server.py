#!/usr/bin/env python3
"""Local development server for the BJC curriculum.

Serves this repository at http://localhost:8000/bjc-r/, matching the URLs used
in production, so absolute links like `/bjc-r/img/...` resolve correctly.

    ./run-server                 # http on port 8000, opens a browser
    ./run-server 9000            # http on port 9000
    ./run-server --https         # https, generating a cert if needed
    ./run-server --make-cert     # regenerate the self-signed cert and exit
    ./run-server --no-open       # don't open a browser
"""

import argparse
import contextlib
import errno
import ssl
import sys
import webbrowser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import dev_cert

REPO_ROOT = Path(__file__).resolve().parent.parent

# Content links are absolute and rooted at /bjc-r/, so requests arrive with that
# prefix even though the checkout itself is the document root.
URL_PREFIX = "/bjc-r"

DEFAULT_PORT = 8000

# The files an author edits directly, matching the no-cache `filesMatch` rule in
# .htaccess. Everything else caches normally.
UNCACHED_SUFFIXES = (".html", ".htm", ".css", ".js", ".topic", ".xml")

CONNECTION_TIMEOUT = 30


class BJCRequestHandler(SimpleHTTPRequestHandler):
    """Serves the checkout under /bjc-r/, CORS-open, authored files uncached."""

    # Keep-alive. Under the HTTP/1.0 default every asset needed a fresh
    # connection, which over TLS meant a fresh handshake per file.
    protocol_version = "HTTP/1.1"

    timeout = CONNECTION_TIMEOUT

    # Headers and body are written separately; without this, Nagle holds the
    # second write for a ~40ms delayed ACK on every file.
    disable_nagle_algorithm = True

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(REPO_ROOT), **kwargs)

    def translate_path(self, path):
        if path == URL_PREFIX:
            path = "/"
        elif path.startswith(URL_PREFIX + "/") or path.startswith(URL_PREFIX + "?"):
            path = path[len(URL_PREFIX):]
        return super().translate_path(path)

    def is_authored_file(self):
        # `path` is unset when the request line itself was malformed.
        path = getattr(self, "path", "").split("?", 1)[0].split("#", 1)[0]
        # A directory URL serves the index.html inside it.
        return path.endswith("/") or path.lower().endswith(UNCACHED_SUFFIXES)

    def send_head(self):
        if self.path == "/":
            self.send_response(302)
            self.send_header("Location", URL_PREFIX + "/")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return None

        if self.is_authored_file():
            # A reload must show the file you just saved, so never answer with
            # "304 Not Modified".
            del self.headers["If-Modified-Since"]
            del self.headers["If-None-Match"]
        return super().send_head()

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Credentials", "true")
        self.send_header("Vary", "Origin")
        if self.is_authored_file():
            self.send_header("Cache-Control",
                             "no-store, no-cache, must-revalidate, max-age=0")
            self.send_header("Pragma", "no-cache")
            self.send_header("Expires", "0")
        super().end_headers()


class DevHTTPServer(ThreadingHTTPServer):
    """Threaded, so one slow or abandoned connection can't stall the others."""

    def handle_error(self, request, client_address):
        # Browsers open speculative connections and abandon them, and cancel
        # image loads mid-download. Neither is worth a traceback.
        if isinstance(sys.exc_info()[1], (ssl.SSLError, ConnectionError, TimeoutError)):
            return
        super().handle_error(request, client_address)


class DevHTTPSServer(DevHTTPServer):
    """Adds TLS, keeping the handshake off the accept loop.

    Wrapping the listening socket (what http.server's own HTTPSServer does)
    runs every handshake inside the single accept loop, so one browser opening
    a connection it never uses blocks every other request.
    """

    def __init__(self, server_address, handler_class, ssl_context):
        self.ssl_context = ssl_context
        super().__init__(server_address, handler_class)

    def get_request(self):
        connection, address = super().get_request()
        return self.ssl_context.wrap_socket(
            connection, server_side=True, do_handshake_on_connect=False
        ), address

    def finish_request(self, request, client_address):
        # Runs on a worker thread, so a slow handshake only affects its own
        # connection.
        request.settimeout(CONNECTION_TIMEOUT)
        request.do_handshake()
        super().finish_request(request, client_address)


def start_server(port, context):
    address = ("localhost", port)
    try:
        if context:
            return DevHTTPSServer(address, BJCRequestHandler, context)
        return DevHTTPServer(address, BJCRequestHandler)
    except OSError as error:
        if error.errno != errno.EADDRINUSE:
            raise
        # Here is how to find what is running on port 8000.
        sys.exit(f"Port {port} is already in use. To see what has it:\n"
                 f"  lsof -i tcp:{port}\n"
                 f"Then stop it, or pick another port: ./run-server {port + 1}")


def parse_args():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("port", nargs="?", type=int, default=DEFAULT_PORT,
                        help=f"port to listen on (default: {DEFAULT_PORT})")
    parser.add_argument("--https", action="store_true",
                        help="serve over TLS using a self-signed certificate")
    parser.add_argument("--make-cert", action="store_true",
                        help="regenerate the self-signed certificate and exit")
    parser.add_argument("--no-open", action="store_true",
                        help="do not open a browser window")
    return parser.parse_args()


def main():
    args = parse_args()

    if args.make_cert:
        dev_cert.generate()
        return

    context = dev_cert.ssl_context() if args.https else None
    server = start_server(args.port, context)
    url = f"{'https' if args.https else 'http'}://localhost:{args.port}{URL_PREFIX}/"

    print(f"Serving {REPO_ROOT} at {url}")
    print("Press Control-C to stop.")

    if not args.no_open:
        webbrowser.open(url)

    with server:
        with contextlib.suppress(KeyboardInterrupt):
            server.serve_forever()
        print("\nStopped.")


if __name__ == "__main__":
    main()
