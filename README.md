# Basic Nix F* package manager

This repo furnishes a sort of basic F* package manager thanks to nix. It basically provides an [overlay](https://nixos.wiki/wiki/Overlays), that bring a default `fstar` package, and a `fstar-package-manager` expression.

## Example

```nix
(import <nixpkgs> {}).fstar-package-manager
  { name = "MyFantasticPackage";
    sources-directory = ./.; # current directory
    sources = [
      "Fantastic.Module.A"
      "Fantastic.Module.B"
      "Fantastic.Module.C"
	  ...
    ];
    ocaml-sources = [
      "MyIO.ml"
    ];
    dependencies = [(import ./StarCombinator)];
    compile = [{
      module = "Main";
      assets = [];
      binary-name = "main-example";
    }];
  }
```

Then `nix-build` (will make a `result` folder in which binaries will be bilt), or `nix-shell` (will bring a shell with a `fstar.exe` pre-configured with paths of dependencies).

## TODO
 - [ ] let a package provide tactics
 - [ ] let a package have tactic dependencies
 - [ ] add kremlin compilation
 - [ ] unsafe tactic flag?

