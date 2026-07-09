function buildReportExportPayload(items) {
  return {
    kind: "report export",
    count: items.length,
    items
  };
}

module.exports = {
  buildReportExportPayload
};

if (require.main === module) {
  const payload = buildReportExportPayload(["fixture"]);
  console.log(JSON.stringify(payload));
}
