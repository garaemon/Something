const { chromium } = require('playwright');
const path = require('path'); const fs = require('fs');
(async () => {
  const out = path.join(__dirname, 'frames'); fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 400, height: 400 } });
  page.on('pageerror', (e) => console.log('pageerror:', e.message));
  await page.goto('http://localhost:8765/index.html');
  await page.waitForFunction('window.ready === true', null, { timeout: 30000 });
  const names = await page.evaluate('window.animNames');
  const N = await page.evaluate('window.frameCount');
  for (const n of names) for (let f = 0; f < N; f++) {
    const url = await page.evaluate(([n, t]) => window.renderFrame(n, t), [n, f]);
    fs.writeFileSync(path.join(out, `${n}_${String(f).padStart(2, '0')}.png`), Buffer.from(url.split(',')[1], 'base64'));
  }
  console.log(names.join(','));
  await browser.close();
})();
