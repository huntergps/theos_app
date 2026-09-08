#!/usr/bin/env python3
"""Small, redacted JSON-2 contract harness for the ERP2 test tenant.

Read-only discovery is the default. This module deliberately makes no request
when imported; run it explicitly with ERP2_URL and ERP2_API_KEY in the env.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

REQUIRED = {
    "res.users": {"read": ["id", "name", "company_id", "company_ids"]},
    "res.partner": {"search_read": ["id", "name", "vat"]},
    "product.product": {"search_read": ["id", "name", "list_price", "uom_id", "taxes_id"]},
    "account.payment.term": {"search_read": ["id", "name", "line_ids"]},
    "account.tax": {"search_read": ["id", "name", "amount"]},
    "product.pricelist": {"search_read": ["id", "name"]},
    "stock.warehouse": {"search_read": ["id", "name", "company_id"]},
    "account.journal": {"search_read": ["id", "name", "type", "company_id"]},
    "sale.order": {"search_read": ["id", "name", "state", "partner_id", "write_date"]},
}
ACTORS = ["seller", "cashier", "approver", "view_all", "offline_operator"]
SCENARIOS = ["cash", "credit", "mixed", "FSC_cash", "offline_create_replay", "approval_required"]
SENSITIVE = re.compile(r"(key|token|secret|password|authorization|cookie)", re.I)


def redacted(value):
    if isinstance(value, dict):
        return {k: "[REDACTED]" if SENSITIVE.search(k) else redacted(v) for k, v in value.items()}
    if isinstance(value, list):
        return [redacted(v) for v in value]
    return value


def host(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise ValueError("ERP2_URL must be an http(s) URL")
    name = parsed.hostname.lower()
    if "newerp" in name:
        raise ValueError("newerp is prohibited by the ERP2 harness")
    return name


def call(url: str, api_key: str, model: str, method: str, kwargs: dict) -> object:
    endpoint = url.rstrip("/") + "/json/2/" + urllib.parse.quote(model, safe="") + "/" + method
    request = urllib.request.Request(
        endpoint,
        data=json.dumps(kwargs).encode(),
        headers={"Authorization": "bearer " + api_key, "Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.loads(response.read())


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify ERP2 JSON-2 contracts (read-only by default).")
    parser.add_argument("--allow-test-writes", action="store_true")
    parser.add_argument("--host", help="required write host, exactly erp2.tecnosmart.com.ec")
    parser.add_argument("--evidence", default="docs/orbi_panel/reports/erp2-verification.json")
    args = parser.parse_args()
    url = os.environ.get("ERP2_URL", "")
    api_key = os.environ.get("ERP2_API_KEY", "")
    evidence = {"timestamp": datetime.now(timezone.utc).isoformat(), "mode": "read_only", "actors": ACTORS, "scenarios": SCENARIOS, "checks": []}
    try:
        name = host(url)
        if not api_key:
            raise ValueError("ERP2_API_KEY is missing")
        if args.allow_test_writes:
            if args.host != "erp2.tecnosmart.com.ec" or name != args.host:
                raise ValueError("writes require --host erp2.tecnosmart.com.ec and matching ERP2_URL")
            evidence["mode"] = "test_write"
        for model, methods in REQUIRED.items():
            for method, fields in methods.items():
                kwargs = {"domain": [], "fields": fields, "limit": 1} if method == "search_read" else {"fields": fields}
                result = call(url, api_key, model, method, kwargs)
                evidence["checks"].append({"model": model, "method": method, "fields": fields, "ok": True, "shape": type(result).__name__})
    except (ValueError, urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
        evidence["error"] = str(error)
        evidence["ok"] = False
    else:
        evidence["ok"] = True
    Path(args.evidence).parent.mkdir(parents=True, exist_ok=True)
    Path(args.evidence).write_text(json.dumps(redacted(evidence), indent=2) + "\n")
    print(json.dumps(redacted({"ok": evidence.get("ok", False), "mode": evidence["mode"], "evidence": args.evidence}), indent=2))
    return 0 if evidence.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
