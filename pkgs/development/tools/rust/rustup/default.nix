{ stdenv, lib, runCommand, patchelf
, fetchFromGitHub, rustPlatform, makeWrapper
, pkgconfig, curl, zlib, Security, CoreServices }:

let
  libPath = lib.makeLibraryPath [
    zlib # libz.so.1
  ];
in

rustPlatform.buildRustPackage rec {
  pname = "rustup";
  version = "1.23.1";

  src = fetchFromGitHub {
    owner = "rust-lang";
    repo = "rustup";
    rev = version;
    sha256 = "1i3ipkq6j47bf9dh9j3axzj6z443jm4j651g38cxyrrx8b2s15x0";
  };

  cargoSha256 = "1zkrrg5m0j9rk65g51v2zh404529p9z84qqb7bfyjmgiqlnh48ig";

  nativeBuildInputs = [ makeWrapper pkgconfig ];

  buildInputs = [
    curl zlib
  ] ++ stdenv.lib.optionals stdenv.isDarwin [ CoreServices Security ];

  cargoBuildFlags = [ "--features no-self-update" ];

  patches = lib.optionals stdenv.isLinux [
    (runCommand "0001-dynamically-patchelf-binaries.patch" { CC=stdenv.cc; patchelf = patchelf; libPath = "$ORIGIN/../lib:${libPath}"; } ''
     export dynamicLinker=$(cat $CC/nix-support/dynamic-linker)
     substitute ${./0001-dynamically-patchelf-binaries.patch} $out \
       --subst-var patchelf \
       --subst-var dynamicLinker \
       --subst-var libPath
    '')
  ];

  doCheck = !stdenv.isAarch64 && !stdenv.isDarwin;

  postInstall = ''
    pushd $out/bin
    mv rustup-init rustup
    binlinks=(
      cargo rustc rustdoc rust-gdb rust-lldb rls rustfmt cargo-fmt
      cargo-clippy clippy-driver cargo-miri
    )
    for link in ''${binlinks[@]}; do
      ln -s rustup $link
    done
    popd

    wrapProgram $out/bin/rustup --prefix "LD_LIBRARY_PATH" : "${libPath}"

    # tries to create .rustup
    export HOME=$(mktemp -d)
    mkdir -p "$out/share/"{bash-completion/completions,fish/vendor_completions.d,zsh/site-functions}

    # generate completion scripts for rustup
    $out/bin/rustup completions bash rustup > "$out/share/bash-completion/completions/rustup"
    $out/bin/rustup completions fish rustup > "$out/share/fish/vendor_completions.d/rustup.fish"
    $out/bin/rustup completions zsh rustup >  "$out/share/zsh/site-functions/_rustup"

    # generate completion scripts for cargo
    # Note: fish completion script is not supported.
    $out/bin/rustup completions bash cargo > "$out/share/bash-completion/completions/cargo"
    $out/bin/rustup completions zsh cargo >  "$out/share/zsh/site-functions/_cargo"
  '';

  meta = with stdenv.lib; {
    description = "The Rust toolchain installer";
    homepage = "https://www.rustup.rs/";
    license = with licenses; [ asl20 /* or */ mit ];
    maintainers = [ maintainers.mic92 ];
  };
}
