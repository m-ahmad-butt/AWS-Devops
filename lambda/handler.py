import base64
import json
import os
import time

import boto3

s3 = boto3.client("s3")
BUCKET = os.environ["BUCKET"]
PREFIX = os.environ["PREFIX"].rstrip("/")
FN_NAME = os.environ.get("AWS_LAMBDA_FUNCTION_NAME", "unknown")


def _key_for_path(path: str) -> str | None:
    if path in ("/", "", "/index.html"):
        return f"{PREFIX}/index.html"
    if path == "/style.css":
        return f"{PREFIX}/style.css"
    if path == "/cv.pdf":
        return f"{PREFIX}/cv.pdf"
    return None


def _log(path: str, status: int, ms: int) -> None:
    print(
        json.dumps(
            {
                "fn": FN_NAME,
                "path": path,
                "status": status,
                "ms": ms,
            }
        )
    )


def handler(event, context):
    started = time.time()
    raw_path = event.get("rawPath") or event.get("path") or "/"
    path = raw_path.split("?")[0] or "/"

    key = _key_for_path(path)
    if key is None:
        body = "<!DOCTYPE html><html><body><h1>404 Not Found</h1><p>No such page.</p></body></html>"
        status = 404
        _log(path, status, int((time.time() - started) * 1000))
        return {
            "statusCode": status,
            "headers": {"Content-Type": "text/html; charset=utf-8"},
            "body": body,
        }

    try:
        obj = s3.get_object(Bucket=BUCKET, Key=key)
        data = obj["Body"].read()
    except Exception:
        body = "<!DOCTYPE html><html><body><h1>404 Not Found</h1><p>Object missing.</p></body></html>"
        status = 404
        _log(path, status, int((time.time() - started) * 1000))
        return {
            "statusCode": status,
            "headers": {"Content-Type": "text/html; charset=utf-8"},
            "body": body,
        }

    if key.endswith("index.html"):
        text = data.decode("utf-8").replace("{{HOSTED_ON}}", f"Lambda {FN_NAME}")
        status = 200
        _log(path, status, int((time.time() - started) * 1000))
        return {
            "statusCode": status,
            "headers": {
                "Content-Type": "text/html; charset=utf-8",
                "Cache-Control": "max-age=60",
            },
            "body": text,
        }

    if key.endswith("style.css"):
        status = 200
        _log(path, status, int((time.time() - started) * 1000))
        return {
            "statusCode": status,
            "headers": {"Content-Type": "text/css"},
            "body": data.decode("utf-8"),
        }

    # PDF — binary, base64 with flag
    status = 200
    _log(path, status, int((time.time() - started) * 1000))
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/pdf"},
        "body": base64.b64encode(data).decode("ascii"),
        "isBase64Encoded": True,
    }
