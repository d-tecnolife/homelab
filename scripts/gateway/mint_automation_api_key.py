#!/usr/bin/env python3
"""Log into Gateway's GUI with a real session (like a browser would) and
mint a homelab-automation API key via OPNsense's addApiKey REST action.

Standard-library only (urllib + http.cookiejar) so it runs anywhere python3
does, with no extra Ops dependencies. Invoked by mint-automation-api-key.sh,
which supplies GATEWAY_ROOT_PASSWORD via `sops exec-env` and passes the
output file path as the sole argument.
"""
import http.cookiejar
import json
import os
import re
import ssl
import sys
import urllib.error
import urllib.request
from urllib.parse import urlencode

GATEWAY_URL = "https://172.16.10.1"
AUTOMATION_USER = "homelab-automation"

CSRF_RE = re.compile(
    r'<input type="hidden" name="([^"]+)" value="([^"]+)" autocomplete="new-password"'
)


def build_opener():
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    cookie_jar = http.cookiejar.CookieJar()
    return urllib.request.build_opener(
        urllib.request.HTTPCookieProcessor(cookie_jar),
        urllib.request.HTTPSHandler(context=ctx),
    ), cookie_jar


def fetch_csrf(opener):
    with opener.open(GATEWAY_URL + "/", timeout=15) as resp:
        body = resp.read().decode("utf-8", errors="replace")
    match = CSRF_RE.search(body)
    if not match:
        print("could not find CSRF token on login page", file=sys.stderr)
        sys.exit(1)
    return match.group(1), match.group(2), body


def main():
    if len(sys.argv) != 2:
        print("usage: mint_automation_api_key.py <output-json-path>", file=sys.stderr)
        sys.exit(2)
    output_path = sys.argv[1]

    password = os.environ.get("GATEWAY_ROOT_PASSWORD")
    if not password:
        print("GATEWAY_ROOT_PASSWORD must be set (via sops exec-env)", file=sys.stderr)
        sys.exit(1)

    opener, _ = build_opener()

    csrf_field, csrf_value, _ = fetch_csrf(opener)

    login_body = urlencode(
        {
            "usernamefld": "root",
            "passwordfld": password,
            "login": "1",
            csrf_field: csrf_value,
        }
    ).encode("ascii")

    req = urllib.request.Request(GATEWAY_URL + "/", data=login_body, method="POST")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")
    with opener.open(req, timeout=15) as resp:
        login_response_body = resp.read().decode("utf-8", errors="replace")

    if 'name="passwordfld"' in login_response_body:
        print("login failed: still on the login page after POST", file=sys.stderr)
        sys.exit(1)

    # Fetch a fresh CSRF token for the authenticated API call.
    api_csrf_field, api_csrf_value, _ = fetch_csrf(opener)

    api_req = urllib.request.Request(
        f"{GATEWAY_URL}/api/auth/user/addApiKey/{AUTOMATION_USER}",
        data=b"",
        method="POST",
    )
    api_req.add_header("X-CSRFToken", api_csrf_value)
    try:
        with opener.open(api_req, timeout=15) as resp:
            status = resp.status
            api_response_body = resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        status = exc.code
        api_response_body = exc.read().decode("utf-8", errors="replace")

    if status != 200:
        print(f"addApiKey request failed: HTTP {status}", file=sys.stderr)
        print(api_response_body, file=sys.stderr)
        sys.exit(1)

    result = json.loads(api_response_body)
    if result.get("result") != "ok":
        print(f"addApiKey did not report success: {result}", file=sys.stderr)
        sys.exit(1)

    with open(output_path, "w", encoding="utf-8") as fh:
        json.dump({"key": result["key"], "secret": result["secret"]}, fh)

    print("addApiKey succeeded")


if __name__ == "__main__":
    main()
