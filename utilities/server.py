#!/usr/bin/env python3
from http.server import HTTPServer, SimpleHTTPRequestHandler, test
import sys, ssl, socketserver, subprocess, time

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
DIRECTORY = "../"

class BJCServer(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers (self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Credentials', 'true')
        self.send_header('Vary', 'Origin')
        SimpleHTTPRequestHandler.end_headers(self)

def https_server():
    # TODO: This is currently very slow to serve files.
    # Generate cert.pem with the following command:
    # openssl req -new -x509 -keyout cert.pem -out cert.pem -days 365 -nodes
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain("utilities/cert.pem")
    server_address = ("localhost", PORT)
    handler = BJCServer
    with socketserver.TCPServer(server_address, handler) as httpd:
        httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
        httpd.serve_forever()

def serve_from_port():
    global PORT
    try:
        test(BJCServer, HTTPServer, port=PORT)
    except:
        PORT += 10
        print(f"Port {PORT-10} seems blocked, using port {PORT}")
        test(BJCServer, HTTPServer, port=PORT)

def open_on_mac():
    has_open = subprocess.run(['which', 'open'])
    if has_open.returncode == 0:
        subprocess.run(['open', f'http://localhost:{PORT}/bjc-r/'])

if __name__ == '__main__':
    # serve_from_port()
    # open_on_mac()
    test(BJCServer, HTTPServer, port=PORT)
