#!/usr/bin/env python3
"""Exports the Web build and makes it hostable on static hosts with a per-file size cap.

Godot's index.wasm (~40 MB) is split into parts of at most PART_BYTES; a small script
injected into index.html intercepts the engine's fetch of index.wasm and reassembles the
parts in memory. Output: build/web/ (index.html, index.js, index.pck, index.wasm.partN, ...).
Usage: python3 tools/build_web.py [godot-binary]
"""
import os, subprocess, sys, glob

PART_BYTES = 12 * 1024 * 1024
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = os.path.join(root, "build", "web")
godot = sys.argv[1] if len(sys.argv) > 1 else "godot"
os.makedirs(out, exist_ok=True)
for f in glob.glob(os.path.join(out, "*")):
    os.remove(f)
subprocess.run([godot, "--headless", "--path", root, "--export-release", "Web", "build/web/index.html"], check=True,
               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=900)
wasm = os.path.join(out, "index.wasm")
data = open(wasm, "rb").read()
parts = []
for i in range(0, len(data), PART_BYTES):
    name = "index.wasm.part%d" % len(parts)
    open(os.path.join(out, name), "wb").write(data[i:i + PART_BYTES])
    parts.append(name)
os.remove(wasm)
loader = """<script>
// Reassemble index.wasm from size-capped parts (static hosts limit file size).
(function () {
  var PARTS = %s;
  var realFetch = window.fetch.bind(window);
  window.fetch = function (input, init) {
    var url = typeof input === "string" ? input : (input && input.url) || "";
    if (url.split("?")[0].endsWith("index.wasm")) {
      return Promise.all(PARTS.map(function (p) {
        return realFetch(p).then(function (r) { if (!r.ok) throw new Error("missing " + p); return r.arrayBuffer(); });
      })).then(function (bufs) {
        var blob = new Blob(bufs, { type: "application/wasm" });
        return new Response(blob, { status: 200, headers: { "Content-Type": "application/wasm", "Content-Length": String(blob.size) } });
      });
    }
    return realFetch(input, init);
  };
})();
</script>
""" % ("[" + ",".join('"%s"' % p for p in parts) + "]")
html_path = os.path.join(out, "index.html")
html = open(html_path).read()
marker = '<script src="index.js"></script>'
assert marker in html, "unexpected index.html layout"
html = html.replace(marker, loader + marker)
open(html_path, "w").write(html)
print("web build:", out)
for f in sorted(os.listdir(out)):
    print("  %-32s %8d KB" % (f, os.path.getsize(os.path.join(out, f)) // 1024))
