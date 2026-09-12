import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { createServer } from 'node:http';
import { mkdir, readFile } from 'node:fs/promises';
import { extname, join, resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const assets = join(root, 'android', 'app', 'src', 'main', 'assets', 'diagrams');
const playwrightPath = process.env.PLAYWRIGHT_CORE_PATH
  ?? join(root, 'build', 'diagram-vendor', 'node_modules', 'playwright-core');
const { chromium } = createRequire(import.meta.url)(playwrightPath);
const chromePath = process.env.CHROME_PATH
  ?? 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const allowedFiles = new Set(['index.html', 'app.js', 'mermaid.min.js']);

const server = createServer(async (request, response) => {
  const name = new URL(request.url, 'http://localhost').pathname.slice(1) || 'index.html';
  if (!allowedFiles.has(name)) {
    response.writeHead(404).end();
    return;
  }
  const body = await readFile(join(assets, name));
  const contentType = extname(name) === '.html'
    ? 'text/html; charset=utf-8'
    : 'text/javascript; charset=utf-8';
  response.writeHead(200, { 'Content-Type': contentType, 'Cache-Control': 'no-store' });
  response.end(body);
});

await new Promise((resolveListen, reject) => {
  server.once('error', reject);
  server.listen(0, '127.0.0.1', resolveListen);
});

let browser;
try {
  const port = server.address().port;
  const origin = `http://127.0.0.1:${port}`;
  browser = await chromium.launch({
    executablePath: chromePath,
    headless: true,
    args: ['--disable-gpu', '--disable-background-networking'],
  });
  const page = await browser.newPage({ viewport: { width: 412, height: 915 } });
  await page.route('**/*', async (route) => {
    if (route.request().url().startsWith(origin)) await route.continue();
    else await route.abort();
  });
  await page.goto(`${origin}/index.html`, { waitUntil: 'load' });
  await page.waitForFunction(() => typeof window.renderDiagram === 'function');

  const cases = [
    ['flowchart LR\nA[Start] --> B[Done]', false],
    ['sequenceDiagram\nAlice->>Bob: Hello\nBob-->>Alice: Hi', true],
    ['pie title Pets\n"Dogs" : 6\n"Cats" : 4', false],
    ['flowchart LR\nA --> B\nclick A href "https://example.com" "External link"', false],
    ['%%{init: {"securityLevel": "loose"}}%%\nflowchart LR\nA-->B', false],
    ['---\nconfig:\n  securityLevel: loose\n---\nflowchart LR\nA-->B', false],
    ['flowchart LR\nSECRET_PARSE_TEXT_7f13 -- broken', false],
  ];
  const results = [];

  for (const [source, dark] of cases) {
    results.push(await page.evaluate(async ({ source, dark }) => {
      const rendered = await window.renderDiagram(source, dark);
      return {
        rendered,
        svg: Boolean(document.querySelector('#diagram > svg')),
        blockedNodes: document.querySelectorAll('#diagram a, #diagram image, #diagram foreignObject').length,
        status: document.querySelector('#status').textContent,
        body: document.body.textContent,
        theme: document.documentElement.dataset.theme,
      };
    }, { source, dark }));

    if (results.length === 1) {
      await mkdir(join(root, 'build'), { recursive: true });
      await page.screenshot({ path: join(root, 'build', 'diagram-preview.png'), fullPage: true });
    }
  }

  for (const [index, result] of results.slice(0, 3).entries()) {
    assert.equal(result.rendered, true, `render case ${index + 1} failed: ${result.status}`);
    assert.equal(result.svg, true, `render case ${index + 1} did not produce an SVG`);
    assert.equal(result.blockedNodes, 0, `render case ${index + 1} retained active or embedded content`);
  }
  assert.match(results[0].body, /Start/);
  assert.match(results[0].body, /Done/);
  assert.equal(results[1].theme, 'dark');
  assert.equal(results[3].rendered, false);
  assert.equal(results[3].body.includes('example.com'), false);
  assert.match(results[4].status, /configuration directives are not allowed/i);
  assert.equal(results[4].body.includes('securityLevel'), false);
  assert.match(results[5].status, /configuration directives are not allowed/i);
  assert.equal(results[5].body.includes('securityLevel'), false);
  assert.match(results[6].status, /could not parse/i);
  assert.equal(results[6].body.includes('SECRET_PARSE_TEXT_7f13'), false);

  console.log('Rendered flowchart, sequence, and pie cases in headless Chrome.');
  console.log('Rejected links and config overrides, and kept errors free of source text.');
} finally {
  await browser?.close();
  await new Promise((resolveClose) => server.close(resolveClose));
}
