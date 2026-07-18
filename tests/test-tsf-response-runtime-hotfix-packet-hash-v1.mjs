import assert from "node:assert/strict";
import {
  HASH_DOMAIN,
  buildCanonicalManifest,
  classifyMaterialization,
  compareCanonicalEntries,
  parseCanonicalManifest,
  sha256Bytes,
} from "./support/tsf-canonical-packet-hash.mjs";

let assertions = 0;
function equal(actual, expected, message) { assertions += 1; assert.deepEqual(actual, expected, message); }
function check(value, message) { assertions += 1; assert.ok(value, message); }
function rejects(action, expression, message) {
  assertions += 1;
  assert.throws(action, expression, message);
}

const csvLf = Buffer.from('suite,command,status\n"packet","git cat-file blob","PASS"\n', "utf8");
const csvCrlf = Buffer.from(csvLf.toString("utf8").replace(/\n/g, "\r\n"), "utf8");
const csvSemanticChange = Buffer.from(csvLf.toString("utf8").replace("PASS", "FAIL"), "utf8");
const canonicalHash = sha256Bytes(csvLf);

const exact = classifyMaterialization(csvLf, csvLf, { text: "set", eol: "lf" });
equal(exact.disposition, "EXACT_CANONICAL_BYTES", "exact bytes remain the canonical checkout case");
equal(exact.canonical_sha256, exact.materialized_sha256, "exact canonical and materialized hashes match");

const converted = classifyMaterialization(csvLf, csvCrlf, { text: "set", eol: "lf" });
equal(converted.disposition, "EXPECTED_GIT_TEXT_MATERIALIZATION", "LF and CRLF are separated only as expected Git text materialization");
equal(converted.canonical_sha256, canonicalHash, "canonical Git-blob SHA is stable across checkout materialization");
equal(converted.normalized_sha256, canonicalHash, "normalized checkout bytes reproduce the canonical blob");
equal(converted.normalized_equivalent, true, "normalized CSV logical content remains exact");

const unexplained = classifyMaterialization(csvLf, csvSemanticChange, { text: "set", eol: "lf" });
equal(unexplained.disposition, "UNEXPLAINED_MATERIALIZATION_MISMATCH", "semantic byte change fails closed");
equal(unexplained.normalized_equivalent, false, "normalization cannot conceal a semantic CSV change");

const binaryCanonical = Buffer.from([0, 1, 2, 3, 4]);
const binaryChanged = Buffer.from([0, 1, 9, 3, 4]);
equal(classifyMaterialization(binaryCanonical, binaryChanged, { text: "unset", eol: "unspecified" }).disposition, "UNEXPLAINED_MATERIALIZATION_MISMATCH", "binary mismatch always fails");

const manifestText = buildCanonicalManifest([{ name: "EXECUTED_TEST_COVERAGE.csv", sha256: canonicalHash }]);
check(manifestText.startsWith(`hash_domain=${HASH_DOMAIN}\n`), "manifest explicitly identifies the canonical Git-blob hash domain");
const manifest = parseCanonicalManifest(Buffer.from(manifestText));
equal(manifest.entries.length, 1, "manifest row parses exactly once");
equal(manifest.entries[0].sha256, canonicalHash, "manifest preserves the canonical blob hash");

const missing = compareCanonicalEntries(manifest.entries, []);
equal(missing.missing, ["EXECUTED_TEST_COVERAGE.csv"], "missing packet file fails closed");
const extra = compareCanonicalEntries([], [{ name: "UNLISTED.md", sha256: canonicalHash }]);
equal(extra.unlisted, ["UNLISTED.md"], "extra unlisted packet file fails closed");
const mismatch = compareCanonicalEntries(manifest.entries, [{ name: "EXECUTED_TEST_COVERAGE.csv", sha256: sha256Bytes(csvSemanticChange) }]);
equal(mismatch.mismatches.length, 1, "canonical blob mismatch fails closed");
rejects(() => parseCanonicalManifest(Buffer.from(`${canonicalHash}  EXECUTED_TEST_COVERAGE.csv\n`)), /PACKET_HASH_DOMAIN_INVALID_OR_MISSING/, "manifest without a canonical hash domain is rejected");
rejects(() => buildCanonicalManifest([{ name: "nested/file.md", sha256: canonicalHash }]), /PACKET_MANIFEST_ENTRY_INVALID/, "nested or ambiguous manifest names are rejected");

process.stdout.write(`${JSON.stringify({
  schema_version: "tsf_canonical_packet_hash_adversarial_test_v1",
  status: "PASS",
  assertions,
  hash_domain: HASH_DOMAIN,
  canonical_csv_sha256: canonicalHash,
  crlf_materialized_sha256: sha256Bytes(csvCrlf),
  expected_materialization_disposition: converted.disposition,
}, null, 2)}\n`);
