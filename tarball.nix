{ nativePkgs ? (import ./default.nix {}).pkgs,
crossBuildProject ? import ./cross-build.nix {} }:
nativePkgs.lib.mapAttrs (_: prj:
with prj.haskell-web-api-template;
let
  executable = haskell-web-api-template.haskell-web-api-template.components.exes.haskell-web-api-template;
  binOnly = prj.pkgs.runCommand "haskell-web-api-template-bin" { } ''
    mkdir -p $out/bin
    cp -R ${executable}/bin/* $out/bin/
    ${nativePkgs.nukeReferences}/bin/nuke-refs $out/bin/haskell-web-api-template
  '';

  tarball = nativePkgs.stdenv.mkDerivation {
    name = "haskell-web-api-template-tarball";
    buildInputs = with nativePkgs; [ zip ];

    phases = [ "installPhase" ];

    installPhase = ''
      mkdir -p $out/
      zip -r -9 $out/haskell-web-api-template-tarball.zip ${binOnly}
    '';
  };
in {
 haskell-web-api-template-tarball = tarball;
}
) crossBuildProject
