#!/usr/bin/env python3
"""Self-signed certificate for the local dev server (see server.py).

Certificates are deliberately short-lived throwaway credentials for localhost,
regenerated automatically as they near expiry.
"""

import ssl
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CERT_DIR = REPO_ROOT / "utilities" / "certs"
CERT_FILE = CERT_DIR / "localhost.pem"
KEY_FILE = CERT_DIR / "localhost-key.pem"

DAYS = 30
RENEW_WITHIN_DAYS = 7

# A config file rather than `-addext` flags, which the LibreSSL that macOS ships
# as /usr/bin/openssl doesn't support.
OPENSSL_CONFIG = """
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no

[dn]
CN = localhost
O = BJC local development

[ext]
subjectAltName = DNS:localhost, IP:127.0.0.1, IP:::1
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
"""

TRUST_HINT = f"""\
Your browser will warn that the certificate is untrusted. Click through it, or
on macOS trust it once:
  security add-trusted-cert -r trustRoot \\
      -k ~/Library/Keychains/login.keychain-db {CERT_FILE}"""


def is_fresh():
    """True if a certificate exists and isn't about to expire."""
    if not (CERT_FILE.exists() and KEY_FILE.exists()):
        return False
    checkend = subprocess.run(
        ["openssl", "x509", "-checkend", str(RENEW_WITHIN_DAYS * 86400),
         "-noout", "-in", str(CERT_FILE)],
        capture_output=True,
    )
    return checkend.returncode == 0


def generate():
    """Write a new short-lived certificate and key, replacing any existing pair."""
    try:
        subprocess.run(["openssl", "version"], capture_output=True, check=True)
    except (OSError, subprocess.CalledProcessError):
        sys.exit("openssl is required to generate a certificate, but was not found.")

    CERT_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", suffix=".cnf") as config:
        config.write(OPENSSL_CONFIG)
        config.flush()
        subprocess.run(
            ["openssl", "req", "-x509", "-newkey", "rsa:2048", "-sha256",
             "-days", str(DAYS), "-nodes",
             "-keyout", str(KEY_FILE), "-out", str(CERT_FILE),
             "-config", config.name],
            check=True, capture_output=True,
        )
    KEY_FILE.chmod(0o600)

    print(f"Wrote a {DAYS}-day certificate for localhost:")
    print(f"  {CERT_FILE}")
    print(f"  {KEY_FILE}")
    print(f"\n{TRUST_HINT}")


def ssl_context():
    """An SSL context for localhost, generating the certificate if needed."""
    if not is_fresh():
        print(f"Certificate is {'expiring soon' if CERT_FILE.exists() else 'missing'};"
              " generating a new one.\n")
        generate()
        print()

    # create_default_context picks sensible protocol and cipher settings for us.
    context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
    context.load_cert_chain(CERT_FILE, KEY_FILE)
    context.set_alpn_protocols(["http/1.1"])
    return context
