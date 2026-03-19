const http = require('http');
const crypto = require('crypto');

const MOCK_FIELDS = {
  payperiodstartdate: { value: '2026-02-01', confidence: 0.95 },
  payperiodenddate:   { value: '2026-02-28', confidence: 0.95 },
  paydate:            { value: '2026-02-28', confidence: 0.95 },
  currentgrosspay:    { value: '5000.00',    confidence: 0.95 },
  currentnetpay:      { value: '3800.00',    confidence: 0.90 },
};

const PORT = parseInt(process.env.MOCK_DOC_AI_PORT || '3001');

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);

  if (req.method === 'POST' && url.pathname === '/v1/documents') {
    // Drain request body, then respond
    req.resume();
    req.on('end', () => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        jobId: `mock-job-${crypto.randomUUID()}`,
        status: 'completed',
        matchedDocumentClass: 'Payslip',
        fields: MOCK_FIELDS,
      }));
    });
  } else if (req.method === 'GET' && url.pathname.startsWith('/v1/documents/')) {
    const jobId = url.pathname.split('/')[3];
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      jobId,
      status: 'completed',
      matchedDocumentClass: 'Payslip',
      fields: MOCK_FIELDS,
    }));
  } else {
    res.writeHead(404);
    res.end('Not found');
  }
});

server.listen(PORT, () => {
  console.log(`Mock DocAI server running on port ${PORT}`);
});
