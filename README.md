# Basic Nix F* package manager

This repo furnishes a sort of basic F* package manager thanks to nix. It basically provides an [overlay](https://nixos.wiki/wiki/Overlays), that bring a default `fstar` package, and a `fstar-package-manager` expression.

## Example

```nix
let pkgs = import <nixpkgs> {} in
(
   pkgs # or, if not using the overlay: (import /path/to/this/repo pkgs pkgs)
).fstar-package-manager
  { name = "MyFantasticPackage";
    sources-directory = ./.; # current directory
    sources = [
      "Fantastic.Module.A"
      "Fantastic.Module.B"
      "Fantastic.Module.C"
	  ...
    ];
    ocaml-sources = [
      "NiceOCamlModule.ml"
    ];
    dependencies = [
		(import ./path/to/my/local/fstar/library)
		(import /path/to/another/local/fstar/library)
		(fetchgit {
          url = "https://github.com/someone/some-fstar-library-repo.git";
          rev    = ...; # commit number or tag
          sha256 = ...;
        };)
	];
    compile = [{
      module = "Main";
      assets = [];
      binary-name = "my-fancy-binary";
    }];
  }
```

## How to use

### Installation
1. If you are not using NixOS, you need Nix: `curl https://nixos.org/nix/install | sh`
2. Either:
   a. Add this repo as an [overlay](https://nixos.wiki/wiki/Overlays), by cloning the repo in your `overlays` folder
   b. Clone this repo in some path on your drive, say `/my/path/`

### Get binaries out of an F* project
Write down a `default.nix` (see the example above), and then `nix-build` in that same folder.

### Using it
Write down a `default.nix` (see the example above), and then `nix-shell` in that same folder. A new shell appears, in which `fstar.exe` (and/or `fstar.wrapped`) is a F* preconfigured with every dependencies in F*'s path.

## TODO
 - [ ] let a package provide tactics
 - [ ] let a package have tactic dependencies
 - [ ] add kremlin compilation
 - [ ] unsafe tactic flag?
 - [ ] add paragraph about using with [lorri](https://github.com/target/lorri)
