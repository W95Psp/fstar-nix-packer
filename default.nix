self: super:
let
  get = (import ./factory.nix) super;
  lib = (import <nixpkgs> {}).lib;
in
rec {
  fstar-factory = get;
  fstar-package-manager-bin = 
    (super.writeScriptBin "fstar-package-init" ''
    #!${super.stdenv.shell}
    if [ ! -f ./fstar-package.nix ]; then
      echo '{ name = "PackageName";' > ./fstar-package.nix
      echo '  sources-directory = ./.;' >> ./fstar-package.nix
      echo '  sources = [' >> ./fstar-package.nix
      for f in *.fst; do echo "    \"$\{f%.*}\""  >> ./fstar-package.nix; done;
      echo '  ];' >> ./fstar-package.nix
      echo '  tactic-module = null;' >> ./fstar-package.nix
      echo '  ocaml-sources = [];' >> ./fstar-package.nix
      echo '  dependencies = [];' >> ./fstar-package.nix
      echo '  compile = [];' >> ./fstar-package.nix
      echo '}' >> ./fstar-package.nix
    fi
    echo "(import <nixpkgs> {}).fstar-package-manager.shell (import ./fstar-package.nix)" > shell.nix
    echo "(import <nixpkgs> {}).fstar-package-manager.build (import ./fstar-package.nix)" > default.nix
    '');
  fstar-package-manager =
    let
      pm = import ./package-manager.nix super;
    in { shell = m : super.callPackage (o: (pm o).shell) m;
         build = m : super.callPackage (o: (pm o).build) m;
       };
  fstar-old = get {
     rev = "db1e8d5ea9c41d2b03d82e9117fae842c51b3c00";
     sha256 = "1dwx449l08cd1v34xk7x4kvxxb34axxlql9ilnn6b2clnaflcak5";
  };  
  fstar-clemma-reflection-smtpat = get {
     rev = "0362a90a83bea851fa5e720637f1cb9d3dfe97bc";
     sha256 = "021zsjzzd0xl1j21wl0y2mgs9rg27cmwx94zz23wcqgv2pimmavg";
     recompileFromSourcesUsing = fstar-master;
     otherPreBuildFlags = "
     echo '#### C_Lemma_SMTPat.patch ####'
     ${super.git}/bin/git apply -p1 ${./patches/C_Lemma_SMTPat.patch}    
     echo '#### [DONE] C_Lemma_SMTPat.patch ####'
";
  };
  fstar-normalize-match = get {
     rev = "b278a1bf710273879f1b1a845d0a907d3db99d6a";
     sha256 = "1k0r9qf7kv50p1kmhx1zxzzbidyj6xncpcbfq5sfmdb940hlvygn";
     recompileFromSourcesUsing = fstar-master;
     otherPreBuildFlags = "
patch -i ${./patches/norm-delta-match.patch} ./src/typechecker/FStar.TypeChecker.Normalize.fs

patch -i ${./patches/FStar.Math.Lemmas.fst.patch} ./ulib/FStar.Math.Lemmas.fst
patch -i ${./patches/FStar.Printf.fst.patch} ./ulib/FStar.Printf.fst
patch -i ${./patches/FStar.UInt128.fst.patch} ./ulib/FStar.UInt128.fst
patch -i ${./patches/LowStar.BufferView.Down.fst.patch} ./ulib/LowStar.BufferView.Down.fst
patch -i ${./patches/LowStar.Monotonic.Buffer.fst.patch} ./ulib/LowStar.Monotonic.Buffer.fst
patch -i ${./patches/FStar.Relational.State.fst.patch} ./ulib/legacy/FStar.Relational.State.fst
patch -i ${./patches/FStar.Pointer.Base.fst.patch} ./ulib/legacy/FStar.Pointer.Base.fst
patch -i ${./patches/FStar.Pointer.Base.fsti.patch} ./ulib/legacy/FStar.Pointer.Base.fsti

patch -i ${./patches/LowStar.Literal.fsti.patch} ./ulib/LowStar.Literal.fsti
";
  };
  fstar-local = let pkgs = import <nixpkgs> {}; in
    pkgs.stdenv.mkDerivation {
      name = "home-lucas-fstar";
      src = lib.cleanSource /home/lucas/FStar;
      phases = ["unpackPhase" "patchPhase" "buildPhase"];
      buildPhase = ''
        mkdir $out
        cp -r bin $out/bin
        cp -r ulib $out/ulib
        '';
    };
  # fstar = fstar-local;
  fstar = fstar-normalize-match;
  fstar-master = get {
     rev = "655aab8b44d4274dd60e4867da4ed833c0e6eaf8";
     sha256 = "0j67d8ns6wvqriy37n4wpz2z2sijm27f5m9p1bhka9fn0l01k0fj";
  };
  fstar-tc = get {
     rev = "0ad4b6347b7258abce2dc66cdb8f921f2841b4b4";
     sha256 = "0fsbz7yib214sq0cmpnpwg52lf9jqysbbpmw3pyayz5mqv9id678";
  };
}
