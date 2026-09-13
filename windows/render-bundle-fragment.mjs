#!/usr/bin/env node
import { createHash } from "node:crypto";
import { readdirSync, writeFileSync } from "node:fs";
import { basename, dirname, join, relative, resolve, sep } from "node:path";

const [bundleArgument, outputArgument] = process.argv.slice(2);
if (!bundleArgument || !outputArgument) {
  console.error("usage: render-bundle-fragment.mjs <bundle-root> <output.wxs>");
  process.exit(2);
}

const bundleRoot = resolve(bundleArgument);
const output = resolve(outputArgument);
const files = [];
const directories = new Set();

function visit(directory) {
  for (const entry of readdirSync(directory, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
    const absolute = join(directory, entry.name);
    const relativePath = relative(bundleRoot, absolute).split(sep).join("/");
    if (entry.isSymbolicLink()) throw new Error(`bundle contains unsupported symbolic link: ${relativePath}`);
    if (entry.isDirectory()) {
      directories.add(relativePath);
      visit(absolute);
    } else if (entry.isFile()) {
      files.push({ absolute, relativePath });
      const parent = dirname(relativePath).split(sep).join("/");
      if (parent !== ".") directories.add(parent);
    } else {
      throw new Error(`bundle contains unsupported filesystem entry: ${relativePath}`);
    }
  }
}

visit(bundleRoot);
if (files.length === 0) throw new Error("bundle contains no files");

function id(prefix, value) {
  return `${prefix}_${createHash("sha256").update(value).digest("hex").slice(0, 24)}`;
}

function xml(value) {
  return value.replaceAll("&", "&amp;").replaceAll('"', "&quot;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
}

const children = new Map();
for (const path of [...directories].sort()) {
  const parent = dirname(path).split(sep).join("/");
  const key = parent === "." ? "" : parent;
  if (!children.has(key)) children.set(key, []);
  children.get(key).push(path);
}

function renderDirectories(parent = "", indent = "      ") {
  return (children.get(parent) ?? []).map((path) => {
    const nested = renderDirectories(path, `${indent}  `);
    const open = `${indent}<Directory Id="${id("dir", path)}" Name="${xml(basename(path))}">`;
    return nested ? `${open}\n${nested}\n${indent}</Directory>` : `${open}</Directory>`;
  }).join("\n");
}

const components = files.map(({ absolute, relativePath }) => {
  const parent = dirname(relativePath).split(sep).join("/");
  const directory = parent === "." ? "INSTALLDIR" : id("dir", parent);
  const suffix = id("bundle", relativePath);
  return [
    `      <Component Id="cmp_${suffix}" Directory="${directory}" Guid="*">`,
    `        <File Id="file_${suffix}" Name="${xml(basename(relativePath))}" Source="${xml(absolute)}" KeyPath="yes" />`,
    "      </Component>",
  ].join("\n");
}).join("\n");

const directoryXml = renderDirectories();
const document = `<?xml version="1.0" encoding="utf-8"?>
<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs">
  <Fragment>
    <DirectoryRef Id="INSTALLDIR">
${directoryXml}
    </DirectoryRef>
  </Fragment>
  <Fragment>
    <ComponentGroup Id="BundleFiles">
${components}
    </ComponentGroup>
  </Fragment>
</Wix>
`;

writeFileSync(output, document);
