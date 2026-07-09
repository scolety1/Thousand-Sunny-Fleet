const assert = require("assert");
const { buildReportExportPayload } = require("../src/index");

const payload = buildReportExportPayload(["a", "b"]);

assert.equal(payload.kind, "report export");
assert.equal(payload.count, 2);
