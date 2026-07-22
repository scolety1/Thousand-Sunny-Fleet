import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";

export const HASH_DOMAIN = "CANONICAL_GIT_BLOB_BYTES_V1";
export const MANIFEST_NAME = "SHA256SUMS.txt";

export function sha256Bytes(value) {
  return createHash("sha256").update(value).digest("hex");
}

function git(repositoryRoot, args, { binary = false } = {}) {
  const result = spawnSync("git.exe", ["-C", repositoryRoot, ...args], {
    encoding: binary ? null : "utf8",
    windowsHide: true,
    maxBuffer: 64 * 1024 * 1024,
  });
  if (result.status !== 0) throw new Error(`GIT_PACKET_HASH_COMMAND_FAILED:${args.join(" ")}:${binary ? result.stderr.toString("utf8") : result.stderr}`);
  return result.stdout;
}

function repoPath(value) {
  return value.replace(/\\/g, "/");
}

export function canonicalBlob(repositoryRoot, repositoryRelativePath, { treeish = "HEAD", index = false } = {}) {
  const relative = repoPath(repositoryRelativePath);
  const objectId = String(git(repositoryRoot, ["rev-parse", index ? `:${relative}` : `${treeish}:${relative}`])).trim();
  if (!/^[a-f0-9]{40,64}$/.test(objectId)) throw new Error(`PACKET_BLOB_ID_INVALID:${relative}`);
  const bytes = git(repositoryRoot, ["cat-file", "blob", objectId], { binary: true });
  return { object_id: objectId, bytes, sha256: sha256Bytes(bytes) };
}

function treePacketPaths(repositoryRoot, packetRelativeRoot, { treeish, index }) {
  if (index) {
    const output = String(git(repositoryRoot, ["ls-files", "--stage", "--", packetRelativeRoot]));
    return output.split(/\r?\n/).filter(Boolean).map((line) => line.slice(line.indexOf("\t") + 1));
  }
  return String(git(repositoryRoot, ["ls-tree", "-r", "--name-only", treeish, "--", packetRelativeRoot])).split(/\r?\n/).filter(Boolean);
}

export function parseCanonicalManifest(bytes) {
  const text = Buffer.from(bytes).toString("utf8").replace(/\r\n/g, "\n");
  const lines = text.split("\n").filter((line) => line.length > 0);
  if (lines[0] !== `hash_domain=${HASH_DOMAIN}`) throw new Error("PACKET_HASH_DOMAIN_INVALID_OR_MISSING");
  const entries = [];
  const names = new Set();
  for (const line of lines.slice(1)) {
    const match = /^([a-f0-9]{64})  ([^\\/]+)$/.exec(line);
    if (!match) throw new Error(`PACKET_MANIFEST_ROW_INVALID:${line}`);
    if (names.has(match[2])) throw new Error(`PACKET_MANIFEST_DUPLICATE:${match[2]}`);
    names.add(match[2]);
    entries.push({ sha256: match[1], name: match[2] });
  }
  return { hash_domain: HASH_DOMAIN, entries };
}

export function buildCanonicalManifest(entries) {
  const ordered = [...entries].sort((left, right) => left.name.localeCompare(right.name, "en", { sensitivity: "case" }));
  const names = new Set();
  for (const entry of ordered) {
    if (!/^[a-f0-9]{64}$/.test(entry.sha256) || !entry.name || /[\\/]/.test(entry.name) || names.has(entry.name)) throw new Error(`PACKET_MANIFEST_ENTRY_INVALID:${entry.name}`);
    names.add(entry.name);
  }
  return `${[`hash_domain=${HASH_DOMAIN}`, ...ordered.map((entry) => `${entry.sha256}  ${entry.name}`)].join("\n")}\n`;
}

export function compareCanonicalEntries(manifestEntries, canonicalEntries) {
  const expectedByName = new Map(manifestEntries.map((entry) => [entry.name, entry.sha256]));
  const actualByName = new Map(canonicalEntries.map((entry) => [entry.name, entry.sha256]));
  return {
    missing: manifestEntries.filter((entry) => !actualByName.has(entry.name)).map((entry) => entry.name),
    unlisted: canonicalEntries.filter((entry) => !expectedByName.has(entry.name)).map((entry) => entry.name),
    mismatches: canonicalEntries.filter((entry) => expectedByName.has(entry.name) && expectedByName.get(entry.name) !== entry.sha256)
      .map((entry) => ({ name: entry.name, expected: expectedByName.get(entry.name), observed: entry.sha256 })),
  };
}

function attributes(repositoryRoot, relativePath) {
  const output = String(git(repositoryRoot, ["check-attr", "text", "eol", "--", repoPath(relativePath)]));
  const result = {};
  for (const line of output.split(/\r?\n/).filter(Boolean)) {
    const match = /^.*?: ([^:]+): (.*)$/.exec(line);
    if (match) result[match[1]] = match[2];
  }
  return result;
}

function normalizeCrlf(bytes) {
  return Buffer.from(bytes.toString("binary").replace(/\r\n/g, "\n"), "binary");
}

export function classifyMaterialization(canonicalBytes, localBytes, gitAttributes = {}) {
  const canonicalHash = sha256Bytes(canonicalBytes);
  const localHash = sha256Bytes(localBytes);
  if (canonicalHash === localHash) return { disposition: "EXACT_CANONICAL_BYTES", canonical_sha256: canonicalHash, materialized_sha256: localHash, normalized_equivalent: true };
  const textEnabled = ["set", "auto", "true"].includes(String(gitAttributes.text).toLowerCase()) || String(gitAttributes.eol).toLowerCase() === "lf";
  const normalized = normalizeCrlf(localBytes);
  if (textEnabled && sha256Bytes(normalized) === canonicalHash) {
    return { disposition: "EXPECTED_GIT_TEXT_MATERIALIZATION", canonical_sha256: canonicalHash, materialized_sha256: localHash, normalized_sha256: sha256Bytes(normalized), normalized_equivalent: true };
  }
  return { disposition: "UNEXPLAINED_MATERIALIZATION_MISMATCH", canonical_sha256: canonicalHash, materialized_sha256: localHash, normalized_sha256: sha256Bytes(normalized), normalized_equivalent: false };
}

export function canonicalPacketEntries({ repositoryRoot, packetRelativeRoot, treeish = "HEAD", index = false }) {
  const paths = treePacketPaths(repositoryRoot, packetRelativeRoot, { treeish, index })
    .filter((item) => path.posix.basename(repoPath(item)) !== MANIFEST_NAME);
  const names = new Set();
  return paths.map((relativePath) => {
    const name = path.posix.basename(repoPath(relativePath));
    if (names.has(name)) throw new Error(`PACKET_BASENAME_COLLISION:${name}`);
    names.add(name);
    const blob = canonicalBlob(repositoryRoot, relativePath, { treeish, index });
    return { name, repository_relative_path: repoPath(relativePath), blob_id: blob.object_id, sha256: blob.sha256, size: blob.bytes.length };
  }).sort((left, right) => left.name.localeCompare(right.name, "en", { sensitivity: "case" }));
}

export function verifyCanonicalPacket({ repositoryRoot, packetRelativeRoot, treeish = "HEAD", index = false, verifyMaterialized = true }) {
  const manifestRelativePath = repoPath(path.posix.join(repoPath(packetRelativeRoot), MANIFEST_NAME));
  const manifestBlob = canonicalBlob(repositoryRoot, manifestRelativePath, { treeish, index });
  const manifest = parseCanonicalManifest(manifestBlob.bytes);
  const canonical = canonicalPacketEntries({ repositoryRoot, packetRelativeRoot, treeish, index });
  const { missing, unlisted, mismatches } = compareCanonicalEntries(manifest.entries, canonical);
  const materialized = [];
  if (verifyMaterialized) {
    for (const entry of canonical) {
      const fullPath = path.join(repositoryRoot, ...entry.repository_relative_path.split("/"));
      if (!existsSync(fullPath)) {
        materialized.push({ name: entry.name, disposition: "MATERIALIZED_FILE_MISSING", canonical_sha256: entry.sha256 });
        continue;
      }
      const blob = canonicalBlob(repositoryRoot, entry.repository_relative_path, { treeish, index });
      materialized.push({ name: entry.name, attributes: attributes(repositoryRoot, entry.repository_relative_path), ...classifyMaterialization(blob.bytes, readFileSync(fullPath), attributes(repositoryRoot, entry.repository_relative_path)) });
    }
  }
  const materializationFailures = materialized.filter((entry) => !["EXACT_CANONICAL_BYTES", "EXPECTED_GIT_TEXT_MATERIALIZATION"].includes(entry.disposition));
  const status = missing.length === 0 && unlisted.length === 0 && mismatches.length === 0 && materializationFailures.length === 0 ? "PASS" : "FAIL";
  return {
    schema_version: "tsf_canonical_git_blob_packet_verification_v1",
    status,
    hash_domain: HASH_DOMAIN,
    source: index ? "STAGED_INDEX" : `COMMIT:${treeish}`,
    packet_relative_root: repoPath(packetRelativeRoot),
    manifest_blob_id: manifestBlob.object_id,
    manifest_blob_sha256: manifestBlob.sha256,
    canonical_entries: canonical,
    missing,
    unlisted,
    mismatches,
    materialized,
    materialization_failures: materializationFailures,
  };
}
