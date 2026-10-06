import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, readlinkSync, existsSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

test('DEB stages a closed owner prefix and package-owned public launch links',t=>{
 const root=mkdtempSync(join(tmpdir(),'beskid-deb-prefix-'));
 t.after(()=>rmSync(root,{recursive:true,force:true}));
 const bundle=join(root,'bundle'), capture=join(root,'capture'), tools=join(root,'tools');
 mkdirSync(join(bundle,'bin'),{recursive:true});mkdirSync(capture);mkdirSync(tools);
 for(const name of ['beskid','beskid_lsp','beskid-up'])writeFileSync(join(bundle,'bin',name),'#!/bin/sh\nexit 0\n',{mode:0o755});
 for(const profile of ['debug','release']){
  const directory=join(bundle,'lib/beskid-runtime/abi-5/x86_64-unknown-linux-gnu',profile);
  mkdirSync(directory,{recursive:true});writeFileSync(join(directory,'abi.json'),'layout fixture');
 }
 mkdirSync(join(bundle,'beskid_corelib/beskid_corelib'),{recursive:true});mkdirSync(join(bundle,'beskid_corelib/packages'));
 for(const name of ['.beskid-bundle.sha256','CoreLib.bws','beskid_corelib/corelib.bproj'])writeFileSync(join(bundle,'beskid_corelib',name),'layout fixture');
 writeFileSync(join(bundle,'release-version.txt'),'0.6.0\n');
 writeFileSync(join(tools,'dpkg-deb'),'#!/bin/sh\nset -eu\ncp -a "$3/." "$BESKID_TEST_DEB_CAPTURE/"\nprintf "layout-only fixture" > "$4"\n',{mode:0o755});
 const output=spawnSync('bash',[fileURLToPath(new URL('../deb/build-deb.sh', import.meta.url)),'0.6.0',bundle],{cwd:root,encoding:'utf8',env:{...process.env,PATH:`${tools}:${process.env.PATH}`,BESKID_TEST_DEB_CAPTURE:capture}});
 assert.equal(output.status,0,output.stdout+output.stderr);
 const prefix=join(capture,'usr/lib/beskid');
 assert.equal(existsSync(join(prefix,'bin/beskid')),true,'release payload must live outside the shared /usr inventory');
 assert.equal(readlinkSync(join(capture,'usr/bin/beskid')),'../lib/beskid/bin/beskid');
 assert.equal(existsSync(join(capture,'usr/beskid_corelib')),false);
 assert.equal(existsSync(join(capture,'usr/release-version.txt')),false);
 const receipt=JSON.parse(readFileSync(join(prefix,'.beskid-owner.json')));
 assert.equal(receipt.owner,'debian');assert.equal(receipt.version,'0.6.0');
 assert.equal(Object.keys(receipt.files).some(path=>path.startsWith('../')),false);
 assert.equal(existsSync(join(bundle,'.beskid-owner.json')),false,'packaging must not mutate its verified input');
});
