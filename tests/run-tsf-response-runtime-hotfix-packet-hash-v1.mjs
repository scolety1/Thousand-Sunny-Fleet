import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  buildCanonicalManifest,
  canonicalPacketEntries,
  verifyCanonicalPacket,
} from "./support/tsf-canonical-packet-hash.mjs";

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const packetRelativeRoot = "docs/hq/tsf_v1_response_contract_runtime_cleanliness_hotfix_v1_20260718";
const args = new Set(process.argv.slice(2));
const index = args.has("--index");
const emitManifest = args.has("--emit-manifest");
const treeishIndex = process.argv.indexOf("--treeish");
const treeish = treeishIndex >= 0 ? process.argv[treeishIndex + 1] : "HEAD";

try {
  if (emitManifest) {
    if (!index) throw new Error("PACKET_MANIFEST_EMISSION_REQUIRES_STAGED_INDEX");
    process.stdout.write(buildCanonicalManifest(canonicalPacketEntries({ repositoryRoot, packetRelativeRoot, index: true })));
  } else {
    const result = verifyCanonicalPacket({ repositoryRoot, packetRelativeRoot, treeish, index, verifyMaterialized: true });
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
    if (result.status !== "PASS") process.exitCode = 1;
  }
} catch (error) {
  process.stderr.write(`${error instanceof Error ? error.stack : String(error)}\n`);
  process.exitCode = 1;
}
