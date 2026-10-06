import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync,mkdirSync,writeFileSync,readFileSync,existsSync,rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
test('container staging verifies immutable bundle, stamps only its private copy, and refuses replacement',t=>{
 const root=mkdtempSync(join(tmpdir(),'beskid-container-owner-'));t.after(()=>rmSync(root,{recursive:true,force:true}));
 const target='x86_64-unknown-linux-gnu', version='0.6.0', source=join(root,`beskid-${version}-${target}`), tools=join(root,'tools');
 mkdirSync(join(source,'bin'),{recursive:true});mkdirSync(tools);
 for(const name of ['beskid','beskid_lsp','beskid-up'])writeFileSync(join(source,'bin',name),'tool fixture',{mode:0o755});
 for(const profile of ['debug','release']) {const path=join(source,'lib/beskid-runtime/abi-5',target,profile);mkdirSync(path,{recursive:true});writeFileSync(join(path,'abi.json'),'layout fixture');}
 mkdirSync(join(source,'beskid_corelib/beskid_corelib'),{recursive:true});mkdirSync(join(source,'beskid_corelib/packages'));
 for(const name of ['CoreLib.bws','.beskid-bundle.sha256','beskid_corelib/corelib.bproj'])writeFileSync(join(source,'beskid_corelib',name),'layout fixture');
 writeFileSync(join(source,'release-version.txt'),version+'\n');
 const archive=join(root,'bundle.tar.gz');
 function pack(){const result=spawnSync('tar',['-czf',archive,'-C',root,`beskid-${version}-${target}`]);assert.equal(result.status,0,String(result.stderr));}
 pack();
 writeFileSync(join(tools,'gh'),`#!${process.execPath}\nconst fs=require('node:fs'),p=require('node:path');const a=process.argv.slice(2);fs.appendFileSync(process.env.BESKID_TEST_GH_LOG,JSON.stringify(a)+'\\n');if(a[0]==='api'){console.log(JSON.stringify({assets:[{name:'beskid-${target}.tar.gz',digest:'sha256:'+process.env.BESKID_TEST_DIGEST}]}));}else if(a[0]==='release'&&a[1]==='download'){const name=a[a.indexOf('--pattern')+1],dir=a[a.indexOf('--dir')+1];if(name==='release-state.json')fs.writeFileSync(p.join(dir,name),JSON.stringify({schema_version:1,publishable:true,version:'${version}',available_artifacts:['beskid-${target}.tar.gz']}));else fs.copyFileSync(process.env.BESKID_TEST_ARCHIVE,p.join(dir,name));}else process.exit(1);\n`,{mode:0o755});
 const log=join(root,'gh.log');const destination=join(root,'oci-build/beskid-bundle');
 const env={...process.env,PATH:`${tools}:${process.env.PATH}`,GH_TOKEN:'fixture-token',BESKID_TEST_ARCHIVE:archive,BESKID_TEST_DIGEST:createHash('sha256').update(readFileSync(archive)).digest('hex'),BESKID_TEST_GH_LOG:log};
 const script=fileURLToPath(new URL('../scripts/prepare-container-toolchain.sh', import.meta.url));
 const run=destination=>spawnSync('bash',[script,version,destination],{encoding:'utf8',env});
 const first=run(destination);assert.equal(first.status,0,first.stdout+first.stderr);
 assert.equal(JSON.parse(readFileSync(join(destination,'.beskid-owner.json'))).owner,'container');
 assert.equal(existsSync(join(source,'.beskid-owner.json')),false);
 const requests=readFileSync(log,'utf8');assert.ok(requests.includes(`v${version}`));assert.equal(requests.includes('cli-stable'),false);
 assert.notEqual(run(destination).status,0);assert.equal(readFileSync(log,'utf8'),requests,'existing destination must fail before release lookup');
 writeFileSync(join(source,'.beskid-owner.json'),'conflicting original ownership');pack();
 env.BESKID_TEST_DIGEST=createHash('sha256').update(readFileSync(archive)).digest('hex');
 const conflict=join(root,'rejected');assert.notEqual(run(conflict).status,0);assert.equal(existsSync(conflict),false);
});
