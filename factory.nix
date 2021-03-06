# this nix expression was stolen from https://github.com/blipp/nix-everest
{ stdenv, lib, pkgs, fetchFromGitHub, ocamlPackages, makeWrapper, z3, ... }:
{ rev ? null, sha256 ? null, customSrc ? null, customName ? null
, otherPreBuildFlags ? ""
, recompileFromSourcesUsing ? null # null or fstar existing derivation
}:


# TODO: continue looking here for some more details: https://nixos.org/nixpkgs/manual/#build-phase
assert (
     (rev != null && sha256 != null && customSrc == null)
  || (rev == null && sha256 == null && customSrc != null)
);
stdenv.mkDerivation rec {
  name = "fstar-${if customName == null then version else customName}";
  version = if rev == null then "custom-src" else rev;

  src = if customSrc == null
        then fetchFromGitHub {
          owner = "FStarLang";
          repo = "FStar";
          rev = rev;
          sha256 = sha256;
          fetchSubmodules = false;
        } else customSrc;
  
  nativeBuildInputs = [ makeWrapper ];

  buildInputs = with ocamlPackages; [
    z3 ocaml findlib batteries menhir stdint
    zarith camlp4 yojson pprint
    ulex ocaml-migrate-parsetree process ppx_deriving ppx_deriving_yojson ocamlbuild
  ];

  makeFlags = [ "PREFIX=$(out)" ];

# TODO I don't know if ulib needs to be shebang patched
  preBuild = ''
    patchShebangs src/tools
    patchShebangs bin
    patchShebangs ulib
    ${otherPreBuildFlags}
    ${if recompileFromSourcesUsing == null
      then ""
      else ''
      cp --no-preserve=mode ${recompileFromSourcesUsing}/bin/fstar.exe ./bin/fstar.exe
      chmod +x ./bin/fstar.exe
      make -C src clean_extracted
      make -C src -j6 fstar-ocaml
      ''
     }
  '';
  postBuid = if recompileFromSourcesUsing == null
    then ""
    else ''
         make -C ulib install-fstarlib
         make -C ulib install-fstar-tactics
         ''; #make -C src/ocaml-output install-compiler-lib

  preInstall = ''
    mkdir -p $out/lib/ocaml/${ocamlPackages.ocaml.version}/site-lib/fstarlib
  '';
# I want to do make all
  installFlags = "-C src/ocaml-output";
  # TODO This wrapper should find the z3 path using some command,
  # TODO it should not be hardcoded.
  postInstall = ''
    mkdir -p $out/ulib/; cp -rv ./ulib/ $out/
    wrapProgram $out/bin/fstar.exe --prefix PATH ":" "${lib.getBin z3}/bin"
    
    ln -s $out/lib/ocaml/${ocamlPackages.ocaml.version}/site-lib/fstar-tactics-lib  $out/bin/fstar-tactics-lib
    ln -s $out/lib/ocaml/${ocamlPackages.ocaml.version}/site-lib/fstarlib           $out/bin/fstarlib
    ln -s $out/lib/ocaml/${ocamlPackages.ocaml.version}/site-lib/fstar-compiler-lib $out/bin/fstar-compiler-lib
  '';

  meta = with stdenv.lib; {
    description = "ML-like functional programming language aimed at program verification";
    homepage = https://www.fstar-lang.org;
    license = licenses.asl20;
    platforms = with platforms; darwin ++ linux;
    maintainers = [ "Benjamin Lipp <blipp@mailbox.org>" ];
  };
}
