# Mascot prototype

The three.js prototype that the app's mascot was ported from.
Use it to try changes to the robot's shape, colors, and motion before porting them to Swift, because it renders without a Mac.

`index.html` holds the model, the inverted-pendulum simulation, and the per-state scripts.
The Swift port lives in `Something/Mascot*.swift` and `Something/BalanceSimulation.swift`.
Keep the constants in both places equal when you change one.

## Render frames

The page loads three.js from `node_modules`, so serve this folder over HTTP.
`render.js` expects the server on port 8765 and needs Playwright with Chromium.

```bash
npm install
```

```bash
python3 -m http.server 8765
```

```bash
node render.js
```

`render.js` writes 60 PNG frames for each state into `frames/`.
