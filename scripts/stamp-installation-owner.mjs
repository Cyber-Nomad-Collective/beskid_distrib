#!/usr/bin/env node
// Package an immutable closed private prefix. Runtime verification belongs to beskid_up.
import { createHash } from 'node:crypto';
import { lstatSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export function stampOwner(prefix, owner, version, target) {
  const owners = new Set(['homebrew', 'debian', 'macos-installer', 'windows-installer', 'manual', 'container']);
  if (!owners.has(owner)) throw new Error('unknown package installation owner');
  if (!/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/.test(version)) throw new Error('invalid installation version');
  if (!['x86_64-unknown-linux-gnu','aarch64-apple-darwin','x86_64-pc-windows-msvc'].includes(target)) throw new Error('unsupported distribution target');
  prefix = resolve(prefix);
  if (!lstatSync(prefix).isDirectory() || lstatSync(prefix).isSymbolicLink()) throw new Error('prefix is not a regular directory');
  if (readFileSync(join(prefix, 'release-version.txt'), 'utf8') !== `${version}\n`) throw new Error('release version mismatch');
  const files = new Map();
  function visit(directory, relative = '') {
    for (const name of readdirSync(directory, { encoding: 'buffer' })) {
      const decoded = name.toString('utf8');
      if (!Buffer.from(decoded).equals(name) || decoded.includes('\\')) throw new Error('noncanonical inventory path');
      const path = join(directory, decoded), key = relative ? `${relative}/${decoded}` : decoded;
      const stat = lstatSync(path);
      if (stat.isSymbolicLink() || (!stat.isDirectory() && !stat.isFile())) throw new Error('toolchain has a link or special file');
      if (key === '.beskid-install.json' || key === '.beskid-owner.json') throw new Error('existing conflicting installation receipt');
      if (stat.isDirectory()) visit(path, key);
      else files.set(key, createHash('sha256').update(readFileSync(path)).digest('hex'));
    }
  }
  visit(prefix);
  const ordered = [...files.entries()].sort(([a],[b]) => Buffer.compare(Buffer.from(a),Buffer.from(b)));
  const hash = createHash('sha256').update(Buffer.from('beskid-installation-inventory-v1\0'));
  for (const [path,digest] of ordered) for (const value of [path,digest]) {
    const bytes = Buffer.from(value), length = Buffer.alloc(8); length.writeBigUInt64BE(BigInt(bytes.length)); hash.update(length).update(bytes);
  }
  const receipt = { schema:1, owner, version, target, artifactIdentity:`sha256-beskid-inventory-v1:${hash.digest('hex')}`, files:Object.fromEntries(ordered) };
  writeFileSync(join(prefix,'.beskid-owner.json'), `${JSON.stringify(receipt,null,2)}\n`, { flag:'wx', mode:0o644 });
  return receipt;
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [prefix,owner,version,target,...extra] = process.argv.slice(2);
  if (!target || extra.length) throw new Error('usage: stamp-installation-owner.mjs <private-prefix> <owner> <version> <target>');
  stampOwner(prefix,owner,version,target);
}
