#!/usr/bin/env node

const fs = require('fs');
const os = require('os');
const path = require('path');
const childProcess = require('child_process');

const projectRoot = path.join(__dirname, '..');

function usage() {
  console.error('Usage: node tools/find_solutions.js <panel.json> [--max-paths N]');
  process.exit(2);
}

function luaString(value) {
  return JSON.stringify(value).replace(/\\u2028|\\u2029/g, (character) =>
    `\\${character.charCodeAt(0).toString(16)}`);
}

function toLua(value) {
  if (value === null) return 'nil';
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) throw new Error('panel contains a non-finite number');
    return String(value);
  }
  if (typeof value === 'string') return luaString(value);
  if (Array.isArray(value)) return `{${value.map(toLua).join(',')}}`;
  if (typeof value !== 'object') throw new Error(`unsupported panel value: ${typeof value}`);
  return `{${Object.entries(value).map(([key, child]) => {
    const numeric = Number(key);
    const luaKey = Number.isInteger(numeric) && String(numeric) === key
      ? `[${numeric}]`
      : `[${luaString(key)}]`;
    return `${luaKey}=${toLua(child)}`;
  }).join(',')}}`;
}

const args = process.argv.slice(2);
if (!args[0] || args.includes('--help') || args.includes('-h')) usage();
const panelPath = path.resolve(args[0]);
let maxPaths = 1000000;
for (let index = 1; index < args.length; index += 1) {
  if (args[index] === '--max-paths') {
    maxPaths = Number(args[++index]);
    if (!Number.isSafeInteger(maxPaths) || maxPaths < 1) {
      throw new Error('--max-paths must be a positive integer');
    }
  } else {
    usage();
  }
}

const panel = JSON.parse(fs.readFileSync(panelPath, 'utf8'));
const inputPath = path.join(os.tmpdir(), `moonpanel-solutions-${process.pid}.lua`);
fs.writeFileSync(inputPath, `return ${toLua(panel)}\n`);

try {
  try {
    const output = childProcess.execFileSync('luajit', [
      path.join(projectRoot, 'tools', 'find_solutions.lua'), inputPath, String(maxPaths), panelPath,
    ], { cwd: projectRoot, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
    process.stdout.write(output);
  } catch (error) {
    process.stdout.write(error.stdout || '');
    process.stderr.write(error.stderr || '');
    process.exitCode = error.status || 1;
  }
} finally {
  fs.rmSync(inputPath, { force: true });
}
