import base64
import gzip
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = "rent-a-degen"
SRC = os.path.join(ROOT, APP)
HERE = os.path.join(ROOT, "emulator")

files = {}
for top, _, names in os.walk(SRC):
    for name in sorted(names):
        if name.endswith((".lua", ".json")):
            path = os.path.join(top, name)
            with open(path, encoding="utf-8") as fh:
                files[os.path.relpath(path, SRC)] = fh.read()

order = ["app.json"] + sorted(k for k in files if k != "app.json")
packed = base64.b64encode(gzip.compress(json.dumps({k: files[k] for k in order}).encode(), 9)).decode()

JS = """(async () => {
const APP = %s, CHUNK = 128, PACK = "%s";
const input = document.querySelector("#emu-cmd");
if (!input) throw new Error("Run this on https://solana.com/breakpoint/badge/emulator");
const assign = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set;
const pause = ms => new Promise(done => setTimeout(done, ms));
const run = command => {
  assign.call(input, command);
  input.dispatchEvent(new Event("input", {bubbles: true}));
  input.form.requestSubmit();
};
const b64 = text => {
  const bytes = new TextEncoder().encode(text);
  let s = "";
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
};
const raw = Uint8Array.from(atob(PACK), c => c.charCodeAt(0));
const files = JSON.parse(await new Response(new Blob([raw]).stream().pipeThrough(new DecompressionStream("gzip"))).text());
run("open home");
await pause(600);
for (const [path, text] of Object.entries(files)) {
  const data = b64(text);
  run(`lua put ${APP} ${path} begin`);
  for (let k = 0; k < data.length; k += CHUNK) {
    run(`lua put ${APP} ${path} ${data.slice(k, k + CHUNK)}`);
    if (k / CHUNK %% 20 === 0) await pause(0);
  }
  run(`lua put ${APP} ${path} end`);
  await pause(5);
}
await pause(1500);
run(`lua run ${APP}`);
return `${APP}: ${Object.keys(files).length} files installed`;
})();
""" % (json.dumps(APP), packed)

with open(os.path.join(HERE, "paste.js"), "w") as fh:
    fh.write(JS)
with open(os.path.join(HERE, "files.json"), "w") as fh:
    json.dump(order, fh)
print(f"emulator/paste.js {len(JS)} bytes, {len(order)} files")
