#!/usr/bin/env python3
"""Exports the Web build and makes it hostable on static hosts with a per-file size cap
and a fixed set of served file types.

Godot's index.wasm (~40 MB) is split into parts of at most PART_BYTES named partN.wasm,
and index.pck is renamed game.pck.wasm (hosts that only serve web media types accept
.wasm). A small script injected into the page intercepts the engine's fetches of
index.wasm / index.pck and serves them from the renamed files.

Output in build/web/:
  index.html  full standalone page (any static host)
  play.html   the same page without <html>/<head>/<body>, for hosts that wrap pages
              in their own document skeleton
Usage: python3 tools/build_web.py [godot-binary]
"""
import os, re, subprocess, sys, glob

PART_BYTES = 12 * 1024 * 1024
PCK_NAME = "game.pck.wasm"
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
    name = "part%d.wasm" % len(parts)
    open(os.path.join(out, name), "wb").write(data[i:i + PART_BYTES])
    parts.append(name)
os.remove(wasm)
os.rename(os.path.join(out, "index.pck"), os.path.join(out, PCK_NAME))
loader = """<script>
// Serve index.wasm from size-capped parts and index.pck from its renamed file.
(function () {
  var PARTS = %s;
  var realFetch = window.fetch.bind(window);
  function bytes(p) {
    return realFetch(p).then(function (r) { if (!r.ok) throw new Error("missing " + p); return r.arrayBuffer(); });
  }
  function respond(bufs, type) {
    var blob = new Blob(bufs, { type: type });
    return new Response(blob, { status: 200, headers: { "Content-Type": type, "Content-Length": String(blob.size) } });
  }
  window.fetch = function (input, init) {
    var url = (typeof input === "string" ? input : (input && input.url) || "").split("?")[0];
    if (url.endsWith("index.wasm")) {
      return Promise.all(PARTS.map(bytes)).then(function (b) { return respond(b, "application/wasm"); });
    }
    if (url.endsWith("index.pck")) {
      return bytes("%s").then(function (b) { return respond([b], "application/octet-stream"); });
    }
    return realFetch(input, init);
  };
})();
</script>
""" % ("[" + ",".join('"%s"' % p for p in parts) + "]", PCK_NAME)
html_path = os.path.join(out, "index.html")
html = open(html_path).read()
marker = '<script src="index.js"></script>'
assert marker in html, "unexpected index.html layout"
html = html.replace(marker, loader + marker)
open(html_path, "w").write(html)
# Skeleton-free variant: drop the document wrapper, keep title, styles and scripts.
frag = re.sub(r'<!DOCTYPE html>\s*<html[^>]*>\s*<head>\s*', '', html)
frag = re.sub(r'<meta charset="utf-8">\s*', '', frag)
frag = re.sub(r'<meta name="viewport"[^>]*>\s*', '', frag)
frag = re.sub(r'</head>\s*<body>', '', frag)
frag = re.sub(r'</body>\s*</html>\s*$', '', frag)
open(os.path.join(out, "play.html"), "w").write(frag)
print("web build:", out)
for f in sorted(os.listdir(out)):
    print("  %-32s %8d KB" % (f, os.path.getsize(os.path.join(out, f)) // 1024))
