#!/usr/bin/env python3
"""Scan recent Loki logs for anomalies using the Jev API (TypeSafe).

Pulls a recent window of logs from Loki, batches lines into Jev Noul
questions asked in parallel over shared state, and prints the lines Jev
scores as worth a human's attention. Read-only: makes no changes to Loki,
Jev, or any homelab service.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

JEV_URL = "https://api.typesafe.ai/v1/systemone"
JEV_MODEL = "jev-latest"

ANOMALY_INSTRUCTIONS = (
    "Does `lines[{i}]` describe an error, failure, crash, security event, or other "
    "condition in a homelab service that a human operator should look into?"
)
ANOMALY_CRITERIA = {
    "true": "Indicates a failure, error, crash, security event, or other abnormal condition",
    "false": "Routine, informational, or expected operation with nothing to act on",
}


def query_loki(loki_url: str, query: str, minutes: int, limit: int) -> list[dict]:
    end_ns = time.time_ns()
    start_ns = end_ns - minutes * 60 * 1_000_000_000
    params = {
        "query": query,
        "start": str(start_ns),
        "end": str(end_ns),
        "limit": str(limit),
        "direction": "backward",
    }
    url = f"{loki_url.rstrip('/')}/loki/api/v1/query_range?{urllib.parse.urlencode(params)}"
    with urllib.request.urlopen(url, timeout=30) as resp:
        payload = json.load(resp)

    entries = []
    for stream in payload.get("data", {}).get("result", []):
        labels = stream.get("stream", {})
        for ts_ns, line in stream.get("values", []):
            entries.append({"ts_ns": int(ts_ns), "labels": labels, "line": line})
    entries.sort(key=lambda e: e["ts_ns"])
    return entries


def call_jev(api_key: str, lines: list[str]) -> dict[str, float]:
    questions = {
        str(i): {
            "type": "noul",
            "instructions": ANOMALY_INSTRUCTIONS.format(i=i),
            "criteria": ANOMALY_CRITERIA,
        }
        for i in range(len(lines))
    }
    body = json.dumps(
        {"state": {"lines": lines}, "model": JEV_MODEL, "questions": questions}
    ).encode()

    req = urllib.request.Request(
        JEV_URL,
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
    )

    backoff = 2.0
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                payload = json.load(resp)
            return {qid: ans["noul"] for qid, ans in payload["answers"].items()}
        except urllib.error.HTTPError as exc:
            if exc.code in (429, 529) and attempt < 3:
                time.sleep(backoff)
                backoff *= 2
                continue
            raise RuntimeError(f"Jev request failed: {exc.code} {exc.read().decode(errors='replace')}") from exc

    raise RuntimeError("Jev request failed after retries")


def batched(items: list, size: int):
    for i in range(0, len(items), size):
        yield items[i : i + size]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--loki-url", default="http://172.16.10.20:3100")
    parser.add_argument("--query", default='{job=~".+"}', help="LogQL stream selector")
    parser.add_argument("--minutes", type=int, default=15, help="lookback window")
    parser.add_argument("--limit", type=int, default=500, help="max lines pulled from Loki")
    parser.add_argument("--batch-size", type=int, default=25, help="lines per Jev call")
    parser.add_argument("--threshold", type=float, default=0.7, help="noul score to flag")
    args = parser.parse_args()

    api_key = os.environ.get("JEV_API_KEY")
    if not api_key:
        print("JEV_API_KEY is not set", file=sys.stderr)
        return 1

    entries = query_loki(args.loki_url, args.query, args.minutes, args.limit)
    if not entries:
        print(f"No log lines in the last {args.minutes}m for query {args.query!r}")
        return 0

    flagged = []
    for batch in batched(entries, args.batch_size):
        scores = call_jev(api_key, [e["line"] for e in batch])
        for i, entry in enumerate(batch):
            score = scores[str(i)]
            if score >= args.threshold:
                flagged.append((score, entry))

    flagged.sort(key=lambda pair: pair[0], reverse=True)

    print(f"Scanned {len(entries)} lines, flagged {len(flagged)} at threshold {args.threshold}\n")
    for score, entry in flagged:
        host = entry["labels"].get("host") or entry["labels"].get("instance") or entry["labels"].get("job", "?")
        ts = entry["ts_ns"] / 1_000_000_000
        print(f"[{score:.2f}] {time.strftime('%H:%M:%S', time.localtime(ts))} {host}: {entry['line']}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
