'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const sourcePath = process.argv[2] || '/tmp/moonpanel-windmill.txt';
const luaBinary = process.argv[3] || 'lua';
const caseName = process.argv[4] || 'windmill';
const maximumWork = Math.max(1, Number(process.argv[5]) || 1000);
const timeoutMs = Math.max(1000, Number(process.argv[6]) || 5000);
const iterations = Math.max(1, Number(process.argv[7]) || 1);
const developmentProfile = process.argv[8] !== 'false';
const cacheMode = process.argv[9] || 'warm';
const projectRoot = path.join(__dirname, '../..');

function toLua(value) {
  if (value === null || value === undefined) return 'nil';
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) throw new Error('panel contains a non-finite number');
    return String(value);
  }
  if (typeof value === 'string') return JSON.stringify(value);
  if (Array.isArray(value)) return `{${value.map(toLua).join(',')}}`;
  return `{${Object.entries(value).map(([key, child]) =>
    `[${JSON.stringify(key)}]=${toLua(child)}`).join(',')}}`;
}

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'moonpanel-verifier-'));
const inputPath = path.join(tempDir, 'panel.lua');
fs.writeFileSync(inputPath, `return ${toLua(JSON.parse(fs.readFileSync(sourcePath, 'utf8')))}\n`);
try {
  const result = spawnSync(luaBinary, [path.join(projectRoot, 'tools/benchmarks/verifier.lua'),
    inputPath, caseName, String(maximumWork), String(iterations),
    'dest/lua/moonpanel/canvas/sh_rule_engine.lua', String(developmentProfile),
    cacheMode], {
      cwd: projectRoot, encoding: 'utf8', timeout: timeoutMs, killSignal: 'SIGKILL',
    });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error && result.error.code === 'ETIMEDOUT') {
    process.stderr.write(`benchmark timed out after ${timeoutMs} ms (case=${caseName}, work=${maximumWork})\n`);
    process.exitCode = 124;
  } else if (result.error && result.status === null) throw result.error;
  else process.exitCode = result.status === null ? 1 : result.status;
} finally {
  fs.rmSync(tempDir, {force: true, recursive: true});
}
