"""Regression: POST /model/load warms checkpoints without inference.

Uses a stub Router so no weights are needed. Run: python tests/test_example_server_load.py
"""
import os
import sys

os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
os.environ.setdefault("LAYA_PRELOAD", "0")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
sys.path.insert(0, os.path.join(ROOT, "examples"))

PASS, FAIL = [], []


def ok(name, cond, detail=""):
    (PASS if cond else FAIL).append("%s%s" % (name, ("  -- " + detail) if detail and not cond else ""))
    print("   %s %s%s" % ("PASS" if cond else "FAIL", name, ("  " + detail) if detail and not cond else ""), flush=True)


class _Agent:
    device = type("D", (), {"type": "cuda"})()


class LoadingRouter:
    def __init__(self):
        self._agents = {}
        self.calls = []

    @property
    def loaded(self):
        return list(self._agents.keys())

    def load(self, name):
        from laya.router import normalise_name

        key = normalise_name(name)
        self.calls.append(("load", key))
        self._agents[key] = _Agent()
        return self._agents[key]

    def preload(self, names=None):
        self.calls.append(("preload", names))
        if names is None:
            for n in ("english", "multilingual", "typed-decisions"):
                self.load(n)
        else:
            for n in names:
                self.load(n)
        return self


def main():
    try:
        from fastapi.testclient import TestClient
    except ImportError as exc:
        if (getattr(exc, "name", None) or "").split(".")[0] not in ("fastapi", "httpx", "starlette"):
            raise
        print("SKIP: fastapi/httpx not installed -- pip install laya[serve] httpx")
        return 0
    try:
        import server as demo
    except ImportError as exc:
        if (getattr(exc, "name", None) or "").split(".")[0] not in ("fastapi", "httpx", "starlette", "multipart"):
            raise
        print("SKIP: examples/server.py needs the serve extra -- pip install laya[serve]")
        return 0

    stub = LoadingRouter()
    demo.ROUTER = stub
    client = TestClient(demo.app, raise_server_exceptions=False)

    r = client.post("/model/load", json={"model": "english"})
    body = r.json()
    ok("POST /model/load one checkpoint -> 200", r.status_code == 200, str(r.status_code))
    ok("calls Router.load", stub.calls == [("load", "english")], repr(stub.calls))
    ok("reports loaded", body.get("loaded") == ["english"], repr(body.get("loaded")))
    ok("reports device type", body.get("checkpoint_devices") == {"english": "cuda"},
       repr(body.get("checkpoint_devices")))

    stub2 = LoadingRouter()
    demo.ROUTER = stub2
    r = client.post("/model/load", json={})
    ok("POST /model/load empty body -> 200", r.status_code == 200, str(r.status_code))
    ok("empty body calls preload", stub2.calls and stub2.calls[0][0] == "preload", repr(stub2.calls))

    demo.ROUTER = None
    r = client.post("/model/load", json={"model": "english"})
    ok("no router -> 503", r.status_code == 503, str(r.status_code))

    demo.ROUTER = stub
    r = client.post("/model/load", json={"model": "not-a-checkpoint"})
    ok("unknown checkpoint -> 422", r.status_code == 422, str(r.status_code))

    print("\n%d passed, %d failed" % (len(PASS), len(FAIL)))
    return 1 if FAIL else 0


if __name__ == "__main__":
    raise SystemExit(main())
