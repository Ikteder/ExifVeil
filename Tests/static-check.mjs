import { readFileSync } from "node:fs";
import { globSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";

const root = fileURLToPath(new URL("..", import.meta.url));
const required = [
  "Package.swift",
  "project.yml",
  "App/ExifVeilApp.swift",
  "App/ContentView.swift",
  "Sources/ExifVeilCore/MetadataInspector.swift",
  "Sources/ExifVeilCore/ImageSanitizer.swift",
  "Tests/ExifVeilCoreTests/ExifVeilCoreTests.swift",
  "README.md"
];

for (const relative of required) {
  readFileSync(join(root, relative), "utf8");
}

const yaml = readFileSync(join(root, "project.yml"), "utf8");
if (!yaml.includes('iOS: "17.0"') || !yaml.includes("CODE_SIGNING_ALLOWED: NO")) {
  throw new Error("iOS deployment or CI signing boundary is missing");
}

const appSource = readFileSync(join(root, "App/ContentView.swift"), "utf8");
if (!appSource.includes("PhotosPicker") || !appSource.includes("ShareLink")) {
  throw new Error("The explicit picker/share flow is missing");
}

const swiftFiles = globSync(join(root, "{App,Sources}/**/*.swift"));
const combined = swiftFiles.map((path) => readFileSync(path, "utf8")).join("\n");
for (const forbidden of ["URLSession", "NWConnection", "import Network", "PHPhotoLibrary.requestAuthorization"]) {
  if (combined.includes(forbidden)) throw new Error(`privacy boundary violated by ${forbidden}`);
}

const readme = readFileSync(join(root, "README.md"), "utf8");
if (readme.includes("—")) throw new Error("README contains an em dash");
if (!readme.match(/!\[[^\]]+\]\(docs\/assets\//)) throw new Error("README visual is missing near the project documentation");

console.log(JSON.stringify({
  checks: 8,
  swiftFiles: swiftFiles.length,
  privacyBoundary: "no network APIs or broad Photos authorization",
  readmeEmDashCount: 0
}));
