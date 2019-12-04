self: super:
let
  get = (import ./factory.nix) super;
in
{
  fstar-package-manager = import ./package-manager.nix;
  fstar = get {
     rev = "ee8fffe163172c77a0af32bb848df90a5030b8d8";
     sha256 = "0awzs9qkxq2rbhab490wvfx9wnkcq91k4p5d5zy77djcnlwv7ljb";
  };
}
