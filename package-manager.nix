pkgs@{lib, fstar, symlinkJoin, stdenv, makeWrapper, ocamlPackages, ...}:
let
  isDerivation = lib.isDerivation;
  unique = lib.unique;
  trace = builtins.trace;
  jtrace = x: builtins.trace (builtins.toJSON x);
  default-ocaml-compile-description
  = { module = throw "compile[].module is mandatory: which F* module would you like to compile?";
      assets = [];
      binary-name = throw "compile[].binary-name is mandatory";
      library-name = "";
      extra-no-extract = [];
      extra-fstar-flags = [];
      extra-ocaml-libraries = [];
      extra-ocaml-flags = [];
    };
  default-module-description
  = compile:
    { name              = throw "name is mandatory";
      sources-directory = throw "sources-directory is mandatory";
      dependencies      = throw "dependencies is mandatory";
      sources           = throw "sources is mandatory";
      tactic-module       = null; # TODO, parse and check (should be subset of sources)
      ocaml-sources     = throw "ocaml-sources is mandatory";
      compile = map (x: default-ocaml-compile-description // x) compile;
      extra-fstar-flags = [];
      force-fstar-version = true;
      # if force-fstar-version is false, use fstar from pkgs
      # if force-fstar-version is true, use fstar from ./default.nix
      # if force-fstar-version is a lambda, use `force-fstar-version factory`, with factory being the one described in ./factory.nix
      # otherwise, use directly `force-fstar-version` as fstar
    };
in
let build-from-module-description = module-description:
let
  # Constants
  odir        = "out";
  plugin-odir = odir + "/plugin";
  ocaml-odir  = odir + "/ocaml";
  extract-path        = "extract";
  plugin-extract-path = extract-path + "/plugin";
  ocaml-extract-path  = extract-path + "/ocaml";
  ocaml_packages = ["fstarlib" "fstar-tactics-lib" "fstar-compiler-lib"];

  # Helpers
  translate-fst-module = builtins.replaceStrings ["."] ["_"];
  addFstExt = v:
    if lib.hasSuffix ".fst" v || lib.hasSuffix ".fsti" v
    then v
    else v + ".fst"; 
  copyFile = dest: file: ''cp --no-preserve=mode ${file} ${dest}/'';
  copyMlFiles = dirIn: dirOut: 
    ''for f in ${dirIn}/*.ml; do
        ${copyFile dirOut "$f"}
    done'';
  
  m = default-module-description (module-description.compile or [])
      // module-description // {compile = map (x: default-ocaml-compile-description // x) module-description.compile;};
  fstar-bin = if m.force-fstar-version == false
              then fstar
              else
                if m.force-fstar-version == true
                then ((import ./default.nix) pkgs pkgs).fstar
                else
                  if builtins.typeOf m.force-fstar-version == "lambda"
                  then m.force-fstar-version (import ./factory.nix pkgs)
                  else m.force-fstar-version;
  compute-includes = m:
    # TODO: force-fstar-version should be overriten only if is `true` or `false`
    let includes = (m.override (mm: mm // {force-fstar-version = m.force-fstar-version;})).includes; in
    let includes = m.includes; in
    includes
     ++ lib.flatten (map compute-includes includes)
  ;
  includes-closure
  = unique (compute-includes {includes = map (d: d {nixpkgs = pkgs;}) m.dependencies; override = _: {includes = map (d: d {nixpkgs = pkgs;}) m.dependencies;};});
  modules-closure = unique (lib.flatten (map (m: m.sources) includes-closure) ++ m.sources);
  fstar-cli-lsts = include: extract: load:
    # let
      # load = if m.disable-native == true then [] else load;
    # in
    builtins.concatStringsSep " " (
      map (x: ''--include "${x}"'') (unique include)
      ++ map (x: ''--extract "${x}"'') (unique extract)
      ++ map (x: ''--load "${x}"'') (
        let
          f = x: map (y: ''${x}/${y}'') x.tactics;
          o = pkgs.lib.flatten (map f includes-closure);
          in unique (load ++ o)
      )
      ++ m.extra-fstar-flags
    );
  fstar-cli =
    { codegen                  ? "",
      codegen-lib              ? "",
      odir                     ? "",
      extract                  ? [],
      use_extracted_interfaces ? false,
      include                  ? [],
      load                     ? [],
      record_hints             ? false,
      use_hints                ? false,
      cache_checked_modules    ? false,
      use_hint_hashes          ? false
    }
    :
    let s_codegen = if codegen == "" then "" else ''--codegen "${codegen}"'';
        s_codegen-lib = if codegen-lib == "" then "" else ''--codegen-lib = "${codegen-lib}"'';
        s_odir = if odir == "" then "" else ''--odir "${odir}"'';
        s_use_extracted_interfaces  = if use_extracted_interfaces == false then "" else ''--use_extracted_interfaces true'';
        others = fstar-cli-lsts include extract load;
        s_use_hint_hashes = if use_hint_hashes then "--use_hint_hashes" else "";
        s_record_hints = if record_hints then "--record_hints" else "";
        s_use_hints = if use_hints then "--use_hints" else "";
        s_cache_checked_modules = if cache_checked_modules
                                then "--cache_checked_modules"
                                else "";
        flags = builtins.concatStringsSep " "
          ( builtins.filter (x: x != "")
            [s_codegen s_codegen-lib s_odir s_record_hints s_use_hints
             s_use_extracted_interfaces others s_cache_checked_modules]
          );
        in ''${fstar-bin}/bin/fstar.exe ${flags}'';
all = rec {
  sources = m.sources;
  auto = if pkgs.lib.inNixShell then shell else build;
  the-module-clean-name =  builtins.replaceStrings ["."] ["-"] m.name;
  wrapped-fstar = (symlinkJoin {
          name = "fstar-include-wrapper-" + the-module-clean-name;
          paths = [ fstar-bin ];
          buildInputs = [ makeWrapper ];
          postBuild = (
            let s = ''
          wrapProgram $out/bin/fstar.exe \
            --run "addEnvHooks(){ :; }; source ${ocamlPackages.findlib.setupHook}; addOCamlPath ${fstar-bin}" \
            --add-flags "${
               (fstar-cli-lsts includes-closure [] [])
            }"
          ln -s $out/bin/fstar.exe $out/bin/fstar.wrapped
        ''; in s); 
  });
  module = m;
  the-modules-closure = modules-closure;
  shell = stdenv.mkDerivation {
    modules-closure = the-modules-closure;
    module-clean-name = the-module-clean-name;
    name = "fstar-shell-" + the-module-clean-name;
    buildInputs = [
      wrapped-fstar
    ];
  };
  build = stdenv.mkDerivation rec {
    module-name = m.name;
    modules-closure = the-modules-closure;
    module-clean-name = the-module-clean-name;
    name = "fstar-lib-" + the-module-clean-name;
    buildInputs = (
      # if lib.inNixShell
      # then
        [ wrapped-fstar pkgs.z3 pkgs.utillinux ]
    );
    nativeBuildInputs = [ fstar-bin pkgs.tree ] ++
                        ( if (  (builtins.length m.compile == 0)
                             && (m.tactic-module == null)
                             )
                          then []
                          else (with ocamlPackages;
                            [ ocaml ocamlbuild findlib ppx_deriving
                              pprint ppx_deriving_yojson zarith stdint batteries])
                        );
    src = lib.cleanSource m.sources-directory;
    sources = m.sources;
    includes = map (d: d {nixpkgs = pkgs;}) m.dependencies;
    buildPhase =
      (
        let sources-modules = " " + builtins.concatStringsSep " " (map addFstExt m.sources);
            # tactics-modules = " " + builtins.concatStringsSep " " (map (v: v + ".fst") m.tactics);
        in
        ''
        package_root_folder=$(pwd)
        echo "## OCaml setup, then folder setup"
        source ${ocamlPackages.findlib.setupHook}
        addOCamlPath ${fstar-bin}
        export OCAMLPATH="$OCAMLPATH:${fstar-bin}/bin"
        OCAMLPATH="$OCAMLPATH:${fstar-bin}/bin"
        rm -rf ${odir} bin lib
        mkdir -p ${ocaml-odir} ${plugin-odir} bin lib

        echo "## Extract every modules as OCaml"
        echo "${fstar-cli { include = includes-closure; codegen = "OCaml"; extract = m.sources; odir = ocaml-odir; } + sources-modules}"
        ${fstar-cli { include = includes-closure; codegen = "OCaml"; extract = m.sources; odir = ocaml-odir; } + sources-modules}

        echo "## Copy OCaml dependencies"
        ${builtins.concatStringsSep "\n" (
          map (dep: copyMlFiles (dep+"/"+ocaml-extract-path) ocaml-odir) (map (d: d {nixpkgs = pkgs;}) m.dependencies) # peer dependencies
          ++ map (copyFile ocaml-odir) m.ocaml-sources # raw OCaml dependencies
          ++ map (copyFile plugin-odir) m.ocaml-sources # raw OCaml dependencies
        )}

        echo "## Compile OCaml binaries"
        cd ${ocaml-odir}
        ${builtins.concatStringsSep "\n"
          ( map ({ module, assets, binary-name, library-name, extra-no-extract,
                   extra-fstar-flags, extra-ocaml-libraries, extra-ocaml-flags
                 }: ''
          ocamlbuild -package ${builtins.concatStringsSep "," ocaml_packages} ${translate-fst-module module}.native
          cp --no-preserve=mode ${translate-fst-module module}.native "$package_root_folder/bin/${binary-name}"
          ${if library-name == ""
            then ""
            else ''
                 ocamlbuild -use-ocamlfind -cflag -g -package ${builtins.concatStringsSep "," ocaml_packages} ${translate-fst-module module}.cmxa
                 cp --no-preserve=mode _build/${translate-fst-module module}.cmxa "$package_root_folder/lib/${library-name}"
                 ''
           }
        '') m.compile)}
        cd "$package_root_folder"
        
        echo "## Extract & compile tactic"
        ${if m.tactic-module == null # TODO clean this awful check
          then ""
          else ''
          ${fstar-cli
            { include = includes-closure; codegen = "Plugin"
              ; extract = modules-closure; odir = plugin-odir; } + " " + addFstExt m.tactic-module}
          cd ${plugin-odir}
          echo "################################"
          echo "################################"
          echo "-> COMPILE TACTIC '${m.tactic-module}'"
          ocamlbuild -use-ocamlfind -cflag -g -package fstar-tactics-lib ${translate-fst-module m.tactic-module}.cmxs
          cp _build/${translate-fst-module m.tactic-module}.cmxs $package_root_folder
          cd "$package_root_folder"
          ''
         }
        ''
      );

    tactics = if m.tactic-module == null
              then []
              else [''${translate-fst-module m.tactic-module}''];
    
    installPhase = (
        ''mkdir -p $out/bin $out/lib $out/${ocaml-extract-path} $out/${plugin-extract-path}
          for f in *.cmxs; do 
            cp --no-preserve=mode -r $f $out
          done
          for f in bin/*; do 
            cp --no-preserve=mode -r $f $out/bin
            chmod +x $out/$f
          done
          for f in ${plugin-odir}/*.ml; do 
            cp --no-preserve=mode $f $out/${ocaml-extract-path}/
          done
          
          for f in ${ocaml-odir}/*.ml; do 
            cp --no-preserve=mode $f $out/${ocaml-extract-path}/
          done
          ${builtins.concatStringsSep "\n"
            (map
              (f:
                let fst  = copyFile "$out/"  f;     
                    fsti = copyFile "$out/" (f+"i");
                in ''(${fst} && (${fsti} || true)) || ${fsti}''
              )
              (map addFstExt m.sources))
           } 
          ${builtins.concatStringsSep "\n" (map (copyFile "$out/") m.ocaml-sources)} # TODO: check if useful?
        ''
      );
  };
};
in
all;
    in build-from-module-description

# +# ocamlbuild -use-ocamlfind -cflag -g -package fstar-tactics-lib,fstar-compiler-lib test.cmxs
