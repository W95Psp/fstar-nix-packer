self: super:
let
  get = (import ./factory.nix) super;
in
{
  fstar-package-manager-bin = 
    (super.writeScriptBin "fstar-package-init" ''
    #!${super.stdenv.shell}
    cp -n ${./package_example.nix} fstar-package.nix
    echo "((import <nixpkgs> {}).fstar-package-manager (import ./fstar-package.nix)).shell" > shell.nix
    echo "((import <nixpkgs> {}).fstar-package-manager (import ./fstar-package.nix)).build" > default.nix
    '');
  fstar-package-manager =
       import ./package-manager.nix super;
    # // {override = import ./package-manager.nix;};
  fstar = get {
     rev = "db1e8d5ea9c41d2b03d82e9117fae842c51b3c00";
     sha256 = "1dwx449l08cd1v34xk7x4kvxxb34axxlql9ilnn6b2clnaflcak5";
  };
  fstar-tc = get {
     rev = "0ad4b6347b7258abce2dc66cdb8f921f2841b4b4";
     sha256 = "0fsbz7yib214sq0cmpnpwg52lf9jqysbbpmw3pyayz5mqv9id678";
  };
}
