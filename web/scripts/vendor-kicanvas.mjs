import { createWriteStream } from "node:fs";
import { mkdir, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const webRoot = resolve(here, "..");
const vendorDir = resolve(webRoot, "public", "vendor");
const targetPath = resolve(vendorDir, "kicanvas.js");
const metaPath = resolve(vendorDir, "kicanvas.meta.json");
const sourceUrl =
  process.env.KICANVAS_BUNDLE_URL ?? "https://kicanvas.org/kicanvas/kicanvas.js";

await mkdir(vendorDir, { recursive: true });

const response = await fetch(sourceUrl);

if (!response.ok || !response.body) {
  throw new Error(`Failed to download KiCanvas bundle from ${sourceUrl}`);
}

await new Promise((resolveDownload, rejectDownload) => {
  const stream = createWriteStream(targetPath);
  response.body.pipeTo(
    new WritableStream({
      write(chunk) {
        stream.write(chunk);
      },
      close() {
        stream.end();
        resolveDownload(null);
      },
      abort(error) {
        stream.destroy();
        rejectDownload(error);
      }
    })
  ).catch(rejectDownload);
});

await writeFile(
  metaPath,
  JSON.stringify(
    {
      sourceUrl,
      vendoredAt: new Date().toISOString()
    },
    null,
    2
  ),
  "utf8"
);

console.log(`Vendored KiCanvas bundle to ${targetPath}`);
