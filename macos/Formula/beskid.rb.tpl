require "digest"
require "find"
require "json"

# Beskid Homebrew formula template.
#
# Rendered by the superrepo's Woodpecker release pipeline with:
#   __VERSION__  -> immutable release semver
#   __SHA256__   -> sha256 of the complete darwin-arm64 target bundle
#
# The rendered file is committed to Cyber-Nomad-Collective/beskid_homebrew by
# scripts/ci/publish-homebrew-formula.sh in the superrepo. It is rendered here
# because the release assets live on beskid_compiler, not the superrepo the
# pipeline runs in.
class Beskid < Formula
  desc "Beskid compiler CLI (AOT, host composition)"
  homepage "https://beskid-lang.org"
  license "Apache-2.0"
  url "https://github.com/Cyber-Nomad-Collective/beskid_compiler/releases/download/v__VERSION__/beskid-aarch64-apple-darwin.tar.gz"
  version "__VERSION__"
  sha256 "__SHA256__"

  # The ABI-v5 runtime kit binds raw bytes by sha256. The kit dylibs carry the
  # relocatable ID `@rpath/<basename>`; without this declaration Homebrew rewrites
  # that ID to an opt path and re-signs the file, which fails every compile with
  # ArtifactHashMismatch. Homebrew 4.6.17 introduced `preserve_rpath`; an older
  # Homebrew fails to load this formula, which is the intended fail-closed result.
  preserve_rpath

  # Apple Silicon only: the compiler pipeline builds aarch64-apple-darwin only.
  on_macos do
    on_arm do
      # nothing extra; binary is prebuilt for arm64
    end
    on_intel do
      # No Intel build in v1. Disable cleanly so `brew install` on Intel fails
      # with a clear message rather than a confusing binary error.
      depends_on arch: :arm
    end
  end

  MACHO_MAGIC = [
    "\xcf\xfa\xed\xfe".b, "\xce\xfa\xed\xfe".b, "\xfe\xed\xfa\xcf".b, "\xfe\xed\xfa\xce".b,
    "\xca\xfe\xba\xbe".b, "\xbe\xba\xfe\xca".b, "\xca\xfe\xba\xbf".b, "\xbf\xba\xfe\xca".b,
  ].freeze
  MACHO_DYLIB_FILETYPE = 6
  KIT_SHARED_LIBRARIES = %w[debug release].map do |profile|
    "lib/beskid-runtime/abi-5/aarch64-apple-darwin/#{profile}/shared/libbeskid_runtime.dylib"
  end.freeze

  # Returns nil for a file that is not a Mach-O image, otherwise its file type.
  def self.macho_filetype(path)
    header = File.binread(path, 16)
    return nil if header.nil? || header.bytesize < 4 || !MACHO_MAGIC.include?(header.byteslice(0, 4))
    raise "Beskid payload contains a fat or 32-bit Mach-O image: #{path}" unless header.byteslice(0, 4) == MACHO_MAGIC.first
    raise "Beskid payload contains a truncated Mach-O header: #{path}" if header.bytesize < 16
    header.byteslice(12, 4).unpack1("V")
  end

  # Mach-O install ID, or nil when the image has none (executables).
  def self.install_id(path)
    lines = Utils.safe_popen_read("otool", "-D", path.to_s).lines.map(&:strip).reject(&:empty?)
    lines.length > 1 ? lines.last : nil
  end

  def self.run_paths(path)
    Utils.safe_popen_read("otool", "-l", path.to_s).lines.map(&:strip).select { |line| line.start_with?("cmd LC_RPATH") }
  end

  def self.dependency_names(path)
    Utils.safe_popen_read("otool", "-L", path.to_s).lines.drop(1).map { |line| line.strip.split(" (").first.to_s }.reject(&:empty?)
  end

  # Relocatable payload contract: a dylib is `@rpath/<basename>`, nothing carries a run path,
  # and every dependency is an `@` name or an absolute system path. Anything else would be
  # rewritten by Homebrew after install and break the raw-byte hash binding.
  def self.verify_relocatable_macho(path)
    filetype = macho_filetype(path)
    return if filetype.nil?
    if filetype == MACHO_DYLIB_FILETYPE
      expected = "@rpath/#{File.basename(path)}"
      actual = install_id(path)
      raise "Beskid payload dylib #{File.basename(path)} has install ID #{actual.inspect}, expected #{expected}" unless actual == expected
    end
    raise "Beskid payload Mach-O #{File.basename(path)} carries an LC_RPATH" unless run_paths(path).empty?
    dependency_names(path).each do |name|
      next if name.start_with?("@") || name.start_with?("/usr/lib/") || name.start_with?("/System/Library/")
      raise "Beskid payload Mach-O #{File.basename(path)} has non-system dependency #{name}"
    end
  end

  def install
    required = "4.6.17"
    raise "Beskid requires Homebrew #{required} or newer for preserve_rpath" unless
      defined?(HOMEBREW_VERSION) && Gem::Version.correct?(HOMEBREW_VERSION[/\A\d+(\.\d+)*/].to_s) &&
      Gem::Version.new(HOMEBREW_VERSION[/\A\d+(\.\d+)*/]) >= Gem::Version.new(required)
    libexec.install "bin", "lib", "beskid_corelib", "release-version.txt"
    # Package ownership binds the complete private payload, without a Node dependency.
    raise "Beskid payload version mismatch" unless File.read((libexec/"release-version.txt").to_s) == "#{version}\n"
    files = {}
    Find.find(libexec.to_s) do |path|
      relative = Pathname.new(path).relative_path_from(libexec).to_s
      next if relative == "."
      stat = File.lstat(path)
      raise "Beskid payload contains a link or special file" unless stat.directory? || stat.file?
      raise "Beskid payload contains a link" if stat.symlink?
      raise "Beskid payload contains a conflicting receipt" if [".beskid-owner.json", ".beskid-install.json"].include?(relative)
      next if stat.directory?
      raise "Noncanonical Beskid payload path" unless relative.valid_encoding? && !relative.include?("\\")
      self.class.verify_relocatable_macho(path)
      files[relative] = Digest::SHA256.file(path).hexdigest
    end
    files = files.sort.to_h
    identity = Digest::SHA256.new
    identity.update("beskid-installation-inventory-v1\0")
    files.each do |path, digest|
      [path, digest].each { |value| identity.update([value.bytesize].pack("Q>")); identity.update(value) }
    end
    receipt = { schema: 1, owner: "homebrew", version: version.to_s,
                target: "aarch64-apple-darwin", artifactIdentity: "sha256-beskid-inventory-v1:#{identity.hexdigest}", files: files }
    File.write((libexec/".beskid-owner.json").to_s, JSON.pretty_generate(receipt) + "\n", mode: "wx")
    bin.write_exec_script libexec/"bin/beskid"
    bin.write_exec_script libexec/"bin/beskid_lsp"
    bin.write_exec_script libexec/"bin/beskid-up"
  end

  test do
    # Homebrew runs linkage fixing after `install`; every payload byte must still match the receipt.
    receipt = JSON.parse(File.read((libexec/".beskid-owner.json").to_s))
    assert_equal "homebrew", receipt["owner"]
    refute_empty receipt["files"]
    receipt["files"].each do |relative, digest|
      assert_equal digest, Digest::SHA256.file((libexec/relative).to_s).hexdigest, "#{relative} changed after install"
    end
    KIT_SHARED_LIBRARIES.each do |relative|
      assert_equal "@rpath/libbeskid_runtime.dylib", self.class.install_id(libexec/relative), "#{relative} install ID"
    end

    assert_match "beskid #{version}", shell_output("#{bin}/beskid --version")

    ENV["BESKID_HOME"] = (testpath/"beskid-home").to_s
    ENV["BESKID_CONFIG_DIR"] = (testpath/"beskid-config").to_s
    ENV.delete("BESKID_CORELIB_ROOT")
    ENV.delete("CORELIB_ROOT")
    ENV.delete("BESKID_RUNTIME_PREFIX")
    ENV.delete("BESKID_CLI_BIN")
    project = testpath/"smoke"
    (project/"Src").mkpath
    (project/"Smoke.bproj").write <<~BESKID
      Smoke {
        name    = "Smoke"
        version = "0.1.0"
        root    = "Src"
      }

      target "app" {
        kind  = App
        entry = "Main.bd"
      }
    BESKID
    (project/"Src/Main.bd").write <<~BESKID
      pub i32 Main() {
          return 0;
      }
    BESKID
    cd project do
      system bin/"beskid", "check", "--project", "Smoke.bproj", "--plain"
      system bin/"beskid", "build", "--project", "Smoke.bproj", "--locked", "--plain"
      system bin/"beskid", "run", "--project", "Smoke.bproj", "--locked", "--plain"
    end
  end
end
