import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { stampOwner } from '../scripts/stamp-installation-owner.mjs';

const KIT_DYLIB='lib/beskid-runtime/abi-5/aarch64-apple-darwin/release/shared/libbeskid_runtime.dylib';
const STAGING_ID='/var/folders/zz/abc/T/beskid-native-runtime-58018-release-1790961636526615000-0/libbeskid_runtime.dylib';
// 64-bit little-endian Mach-O header: magic, cputype arm64, subtype, filetype MH_DYLIB.
const machoDylibHeader=()=>{const h=Buffer.alloc(32);h.writeUInt32LE(0xfeedfacf,0);h.writeUInt32LE(0x0100000c,4);h.writeUInt32LE(6,12);return h;};

const harnessSource=String.raw`require 'pathname'
require 'fileutils'
require 'json'
HOMEBREW_VERSION = '4.6.17'
class FixturePath < Pathname
 def install(*names)
  FileUtils.mkdir_p(to_s)
  names.each { |name| FileUtils.cp_r(name, to_s) }
 end
 def write_exec_script(path)
  FileUtils.mkdir_p(to_s)
  File.write((self/path.basename).to_s, "#!/bin/sh\nexec #{path} \"$@\"\n")
 end
end
STUBS = JSON.parse(File.read(ARGV[3]))
module Utils
 def self.safe_popen_read(tool, *args)
  path = args.last
  stub = STUBS.fetch(File.basename(path)) { { 'id' => nil, 'rpaths' => [], 'deps' => [] } }
  case [tool, args.first]
  when ['otool', '-D']
   stub['id'] ? "#{path}:\n#{stub['id']}\n" : "#{path}:\n"
  when ['otool', '-l']
   stub['rpaths'].map { |rpath| "Load command 9\n          cmd LC_RPATH\n      cmdsize 32\n         path #{rpath} (offset 12)\n" }.join
  when ['otool', '-L']
   "#{path}:\n" + (([stub['id']].compact) + stub['deps']).map { |name| "\t#{name} (compatibility version 1.0.0, current version 1.0.0)\n" }.join
  else
   raise "unexpected tool #{tool}"
  end
 end
end
class Formula
 def self.test(&block); end
 def self.method_missing(name,*args,&block)
  block.call if [:on_macos,:on_arm].include?(name)
 end
 def initialize(root)
  @root=root
 end
 def libexec; FixturePath.new(File.join(@root,'private')); end
 def bin; FixturePath.new(File.join(@root,'public')); end
 def version; '0.6.0'; end
end
load ARGV[0]
Dir.chdir(ARGV[1]) { Beskid.new(ARGV[2]).install }
`;

function fixture(t,{withKit=false}={}){
 const root=mkdtempSync(join(tmpdir(),'beskid-brew-owner-'));t.after(()=>rmSync(root,{recursive:true,force:true}));
 const bundle=join(root,'bundle');mkdirSync(bundle);
 for(const name of ['bin','lib','beskid_corelib'])mkdirSync(join(bundle,name));
 for(const name of ['beskid','beskid_lsp','beskid-up'])writeFileSync(join(bundle,'bin',name),'tool fixture');
 writeFileSync(join(bundle,'release-version.txt'),'0.6.0\n');
 if(withKit){mkdirSync(join(bundle,dirname(KIT_DYLIB)),{recursive:true});writeFileSync(join(bundle,KIT_DYLIB),machoDylibHeader());}
 const harness=join(root,'formula-test.rb');
 writeFileSync(harness,harnessSource);
 return {root,bundle,harness};
}
function install({root,bundle,harness},stubs){
 const stubFile=join(root,'otool-stubs.json');writeFileSync(stubFile,JSON.stringify(stubs));
 return spawnSync('ruby',[harness,fileURLToPath(new URL('../macos/Formula/beskid.rb.tpl', import.meta.url)),bundle,root,stubFile],{encoding:'utf8'});
}

test('Homebrew stamps the same framed identity with Ruby standard libraries',t=>{
 const f=fixture(t);const {root,bundle}=f;
 const output=install(f,{});
 assert.equal(output.status,0,output.stdout+output.stderr);
 const receipt=JSON.parse(readFileSync(join(root,'private/.beskid-owner.json')));
 const reference=stampOwner(bundle,'homebrew','0.6.0','aarch64-apple-darwin');
 assert.equal(receipt.owner,'homebrew');assert.equal(receipt.artifactIdentity,reference.artifactIdentity);
 assert.deepEqual(receipt.files,reference.files);
});

test('Homebrew accepts a relocatable @rpath kit dylib and binds its raw bytes',t=>{
 const f=fixture(t,{withKit:true});
 const output=install(f,{'libbeskid_runtime.dylib':{id:'@rpath/libbeskid_runtime.dylib',rpaths:[],deps:['/usr/lib/libSystem.B.dylib','/usr/lib/libc++.1.dylib']}});
 assert.equal(output.status,0,output.stdout+output.stderr);
 const receipt=JSON.parse(readFileSync(join(f.root,'private/.beskid-owner.json')));
 assert.ok(receipt.files[KIT_DYLIB]);
});

test('Homebrew rejects the 0.5.2 staging install ID before writing a receipt',t=>{
 const f=fixture(t,{withKit:true});
 const output=install(f,{'libbeskid_runtime.dylib':{id:STAGING_ID,rpaths:[],deps:['/usr/lib/libSystem.B.dylib']}});
 assert.notEqual(output.status,0);
 assert.match(output.stderr,/install ID/);
 assert.equal(existsSync(join(f.root,'private/.beskid-owner.json')),false);
});

test('Homebrew rejects an absolute LC_RPATH before writing a receipt',t=>{
 const f=fixture(t,{withKit:true});
 const output=install(f,{'libbeskid_runtime.dylib':{id:'@rpath/libbeskid_runtime.dylib',rpaths:['/Users/builder/target/release'],deps:['/usr/lib/libSystem.B.dylib']}});
 assert.notEqual(output.status,0);
 assert.match(output.stderr,/LC_RPATH/);
 assert.equal(existsSync(join(f.root,'private/.beskid-owner.json')),false);
});

test('Homebrew rejects a non-system absolute dependency before writing a receipt',t=>{
 const f=fixture(t,{withKit:true});
 const output=install(f,{'libbeskid_runtime.dylib':{id:'@rpath/libbeskid_runtime.dylib',rpaths:[],deps:['/opt/homebrew/lib/libz.dylib']}});
 assert.notEqual(output.status,0);
 assert.match(output.stderr,/non-system dependency/);
 assert.equal(existsSync(join(f.root,'private/.beskid-owner.json')),false);
});
