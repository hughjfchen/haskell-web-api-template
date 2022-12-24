{ nativePkgs ? (import ./default.nix {}).pkgs,
crossBuildProject ? import ./cross-build.nix {} }:
nativePkgs.lib.mapAttrs (_: prj:
with prj.haskell-web-api-template;
let
  executable = haskell-web-api-template.haskell-web-api-template.components.exes.haskell-web-api-template;
  binOnly = prj.pkgs.runCommand "haskell-web-api-template-bin" { } ''
    mkdir -p $out/bin
    cp ${executable}/bin/haskell-web-api-template $out/bin
    ${nativePkgs.nukeReferences}/bin/nuke-refs $out/bin/haskell-web-api-template
  '';
in { 
  haskell-web-api-template-image = prj.pkgs.dockerTools.buildImage {
  name = "haskell-web-api-template";
  tag = executable.version;
  contents = [ binOnly prj.pkgs.cacert prj.pkgs.iana-etc ];
  config.Entrypoint = "haskell-web-api-template";
  config.Cmd = "--help";
  };
}) crossBuildProject
