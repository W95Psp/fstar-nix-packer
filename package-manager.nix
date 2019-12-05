pkgs@{lib, fstar, symlinkJoin, stdenv, makeWrapper, ocamlPackages, ...}:
let
  default-compile-description
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
    { name = throw "name is mandatory";
      sources-directory = throw "sources-directory is mandatory";
      dependencies = throw "dependencies is mandatory";
      sources = throw "sources is mandatory";
      ocaml-sources = throw "ocaml-sources is mandatory";
      compile = map (x: default-compile-description // x) compile;
      extra-fstar-flags = [];
      skipVerification = false;
      force-fstar-version = true;
      # if force-fstar-version is false, use fstar from pkgs
      # if force-fstar-version is true, use fstar from ./default.nix
      # if force-fstar-version is a lambda, use `force-fstar-version factory`, with factory being the one described in ./factory.nix
      # otherwise, use directly `force-fstar-version` as fstar
    };
in
module-description:
let
  fstar-default = ((import ./default.nix) pkgs pkgs).fstar;
  fstar-factory = (import ./factory.nix) pkgs;
  fstar-bin = if m.force-fstar-version == false
              then fstar
              else
                if m.force-fstar-version == true
                then fstar-default
                else
                  if builtins.typeOf m.force-fstar-version == "lambda"
                  then m.force-fstar-version fstar-factory 
                  else m.force-fstar-version;
  compute-includes = m:
        m.includes
     ++ lib.flatten (map compute-includes m.includes)
  ;
  includes-closure = compute-includes {includes = m.dependencies;};
  odir = "out";
  translate-fst-module = builtins.replaceStrings ["."] ["_"];
  ocaml_packages = ["fstarlib" "fstar-tactics-lib" "fstar-compiler-lib"];
  copyFile = dest: file: ''cp ${file} ${dest}/'';
  m = default-module-description (module-description.compile or [])
      // module-description // {compile = map (x: default-compile-description // x) module-description.compile;};
  fstar-cli-lsts = include: extract: load:
    builtins.concatStringsSep " " (
      map (x: ''--include "${x}"'') include
      ++ map (x: ''--extract "${x}"'') extract
      ++ map (x: ''--load "${x}"'') load
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
  wrapped-fstar = (symlinkJoin {
          name = "fstar-include-wrapper-" + m.name;
          paths = [ fstar-bin ];
          buildInputs = [ makeWrapper ];
          postBuild = ''
          wrapProgram $out/bin/fstar.exe \
            --add-flags "${
              (fstar-cli-lsts includes-closure [] [])
            }"
          ln -s $out/bin/fstar.exe $out/bin/fstar.wrapped
        ''; 
        });
  lib = stdenv.mkDerivation rec {
    name = "fstar-lib-" + m.name;
    buildInputs = (
      # if lib.inNixShell
      # then
        [ wrapped-fstar ]
    );
    nativeBuildInputs = [ fstar-bin ] ++
                        ( if builtins.length m.compile == 0
                          then []
                          else (with ocamlPackages;
                            [ ocaml ocamlbuild findlib ppx_deriving
                              pprint ppx_deriving_yojson zarith stdint batteries])
                        );
    src = m.sources-directory;
    includes = m.dependencies;
    buildPhase =
      (
        let includes = includes-closure;
            checkModule = module: ''${fstar-cli { include = includes; }} ${module}.fst'';
            extract_cmds = map (v: fstar-cli { include = includes; codegen = "OCaml"; extract = m.sources; odir = odir; } + " " + v + ".fst")
              (map ({module, ...}: module) m.compile);
            extract_cmd = builtins.concatStringsSep "\n" extract_cmds;
        in
        ''
        ${
          if m.skipVerification
          then ""
          else builtins.concatStringsSep "\n" (map checkModule m.sources)
         }
        ${
            ''
            rm -rf ${odir} bin lib
            mkdir -p ${odir} bin lib
            ${extract_cmd}
            ${builtins.concatStringsSep "\n" (map (dep: ''
            for f in ${dep}/ocaml/*.ml; do
               cp "$f" ${odir}/
            done
            '') m.dependencies)}
            ${builtins.concatStringsSep "\n" (map (copyFile odir) m.ocaml-sources)}
            
            cd ${odir}
            source ${ocamlPackages.findlib.setupHook}
            addOCamlPath ${fstar-bin}
            ${builtins.concatStringsSep "\n"
              ( map ({ module, assets, binary-name, library-name, extra-no-extract,
                       extra-fstar-flags, extra-ocaml-libraries, extra-ocaml-flags
                     }: ''
              ocamlbuild -package ${builtins.concatStringsSep "," ocaml_packages} ${translate-fst-module module}.native
              cp ${translate-fst-module module}.native ../bin/${binary-name}
              ${if library-name == ""
                then ""
                else ''
                     ocamlbuild -use-ocamlfind -cflag -g -package ${builtins.concatStringsSep "," ocaml_packages} ${translate-fst-module module}.cmxa
                     cp _build/${translate-fst-module module}.cmxa ../lib/${library-name}
                     ''
               }
            '') m.compile)}
            cd ..
            ''
        }
        ''
      );
    
    installPhase = (
        ''mkdir -p $out/bin $out/lib $out/ocaml
          for f in bin/*.ml; do 
            cp -r $f $out/bin
          done
          for f in ${odir}/*.ml; do 
            cp $f $out/ocaml/
          done
          chmod +x $out/bin
          ${builtins.concatStringsSep "\n"
            (map
              (f:
                let fst  = copyFile "$out/"  f;     
                    fsti = copyFile "$out/" (f+"i");
                in ''(${fst} && (${fsti} || true)) || ${fsti}''
              )
              (map (x: x + ".fst") m.sources))
           } 
          ${builtins.concatStringsSep "\n" (map (copyFile "$out/") m.ocaml-sources)}
        ''
      );
  };
};
in
all.lib
