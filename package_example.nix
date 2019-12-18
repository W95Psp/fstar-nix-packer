(import <nixpkgs> {}).fstar-package-manager
  { name = some-name;
    sources-directory = ./.;
    sources = [
      module1 module2
    ];
    ocaml-sources = [];
    dependencies = [];
    compile = [];
  }
