import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, symlinkSync, existsSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { stampOwner } from '../scripts/stamp-installation-owner.mjs';

function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), 'beskid-owner-'));
  t.after(() => rmSync(root,{recursive:true,force:true}));
  mkdirSync(join(root,'bin'));
  writeFileSync(join(root,'bin/beskid'),'compiler');
  writeFileSync(join(root,'release-version.txt'),'0.6.0\n');
  return root;
}
const target = 'x86_64-unknown-linux-gnu';
test('owner receipt frames the complete immutable file inventory',t => {
  const root=fixture(t);
  mkdirSync(join(root,'nested'));
  writeFileSync(join(root,'nested/.beskid-owner.json'),'owned nested data');
  const receipt=stampOwner(root,'debian','0.6.0',target);
  assert.equal(receipt.owner,'debian');
  assert.deepEqual(Object.keys(receipt.files),['bin/beskid','nested/.beskid-owner.json','release-version.txt']);
  assert.equal(receipt.artifactIdentity,'sha256-beskid-inventory-v1:2e1d4872a0b7806a9cf61bd3e4a0c2ed15f0e872682be5dcb3960ba8acd0577a');
  assert.deepEqual(JSON.parse(readFileSync(join(root,'.beskid-owner.json'))),receipt);
});
test('a link or cycle fails before receipt publication and external mutation',t => {
  const root=fixture(t);
  const external=fixture(t);
  symlinkSync(external,join(root,'outside'),'dir');
  assert.throws(()=>stampOwner(root,'debian','0.6.0',target),/link or special/);
  assert.equal(existsSync(join(root,'.beskid-owner.json')),false);
  assert.equal(readFileSync(join(external,'bin/beskid'),'utf8'),'compiler');
});
test('existing receipts and malformed owner coordinates fail closed',t => {
  const root=fixture(t);
  for (const args of [['unknown','0.6.0',target],['debian','0.6.1',target],['debian','0.6.0','fake-target']]) {
    assert.throws(()=>stampOwner(root,...args));
    assert.equal(existsSync(join(root,'.beskid-owner.json')),false);
  }
  writeFileSync(join(root,'.beskid-install.json'),'prior direct identity');
  assert.throws(()=>stampOwner(root,'debian','0.6.0',target),/conflicting/);
  assert.equal(readFileSync(join(root,'.beskid-install.json'),'utf8'),'prior direct identity');
});
