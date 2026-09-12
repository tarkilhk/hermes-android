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
  const unexpectedRequests = [];
  await page.route('**/*', async (route) => {
    const url = new URL(route.request().url());
    if (url.origin === origin && allowedFiles.has(url.pathname.slice(1))) {
      await route.continue();
    } else {
      unexpectedRequests.push(url.href);
      await route.abort();
    }
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

  const svgResults = await page.evaluate(async (origin) => {
    const liveUrls = new Set();
    const create = URL.createObjectURL.bind(URL);
    const revoke = URL.revokeObjectURL.bind(URL);
    URL.createObjectURL = (blob) => {
      const url = create(blob);
      liveUrls.add(url);
      return url;
    };
    URL.revokeObjectURL = (url) => { liveUrls.delete(url); revoke(url); };
    const wrap = (body) => `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">${body}</svg>`;
    const pixel = () => {
      const canvas = document.createElement('canvas');
      canvas.width = canvas.height = 32;
      const context = canvas.getContext('2d');
      context.drawImage(document.querySelector('#diagram img'), 0, 0, 32, 32);
      return [...context.getImageData(16, 16, 1, 1).data];
    };
    const script = wrap('<rect id="target" width="32" height="32" fill="green"/><script>document.getElementById("target").setAttribute("fill","red")</script>');
    const scriptRendered = await window.renderSvg(script, true);
    const scriptPixel = pixel();
    const embedded = wrap(`<style>@import url('${origin}/forbidden.css');</style><image href="${origin}/forbidden.png"/><foreignObject width="32" height="32"><div xmlns="http://www.w3.org/1999/xhtml" onload="fetch('${origin}/forbidden-event')"><img src="${origin}/forbidden-inner.png"/></div></foreignObject><a href="${origin}/forbidden-link"><rect width="32" height="32" fill="blue"/></a>`);
    const embeddedRendered = await window.renderSvg(embedded);
    document.querySelector('#diagram img')?.click();
    const inlineNodes = document.querySelectorAll('#diagram svg, #diagram script, #diagram a, #diagram foreignObject').length;
    const malformed = await window.renderSvg('<svg>SECRET_BAD_SVG');
    const malformedStatus = document.querySelector('#status').textContent;
    const oversized = await window.renderSvg('x'.repeat(256 * 1024 + 1));
    const huge = await window.renderSvg('<svg xmlns="http://www.w3.org/2000/svg" width="9000" height="9000"/>');
    const replacement = await Promise.all([
      window.renderSvg(wrap('<rect width="32" height="32" fill="red"/>')),
      window.renderSvg(wrap('<rect width="32" height="32" fill="blue"/>')),
    ]);
    return { scriptRendered, scriptPixel, embeddedRendered, inlineNodes, malformed,
      malformedStatus, oversized, huge, replacement, finalPixel: pixel(), liveUrls: liveUrls.size };
  }, origin);
  assert.equal(svgResults.scriptRendered, true);
  assert.deepEqual(svgResults.scriptPixel, [0, 128, 0, 255], 'SVG scripts must not change image pixels');
  assert.equal(svgResults.embeddedRendered, true);
  assert.equal(svgResults.inlineNodes, 0);
  assert.equal(svgResults.malformed, false);
  assert.equal(svgResults.malformedStatus.includes('SECRET_BAD_SVG'), false);
  assert.equal(svgResults.oversized, false);
  assert.equal(svgResults.huge, false);
  assert.equal(svgResults.replacement[1], true);
  assert.deepEqual(svgResults.finalPixel, [0, 0, 255, 255]);
  assert.equal(svgResults.liveUrls, 0, 'SVG object URLs must be released');
  assert.deepEqual(unexpectedRequests, [], 'Previews attempted an external or unexpected request');
  assert.equal(page.url(), `${origin}/index.html`);
  assert.equal(await page.evaluate(() => window.renderSvg(
    '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="240" viewBox="0 0 600 240">' +
    '<rect x="10" y="50" width="200" height="120" rx="20" fill="#005f49"/>' +
    '<path d="M210 110 H385 M365 90 L385 110 L365 130" stroke="#147c63" stroke-width="8" fill="none"/>' +
    '<rect x="390" y="50" width="200" height="120" rx="20" fill="#005f49"/>' +
    '<g fill="white" font-family="sans-serif" font-size="32" text-anchor="middle"><text x="110" y="120">Draft</text><text x="490" y="120">Result</text></g></svg>',
  )), true);
  await page.screenshot({ path: join(root, 'build', 'svg-preview.png'), fullPage: true });
  console.log('SVG image context blocks script execution and external content; errors, limits and replacement pass.');
} finally {
  await browser?.close();
  await new Promise((resolveClose) => server.close(resolveClose));
}
