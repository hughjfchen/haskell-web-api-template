{ nativePkgs ? (import ./default.nix {}).pkgs,
crossBuildProject ? import ./cross-build.nix {} }:
nativePkgs.lib.mapAttrs (_: prj:
with prj.haskell-web-api-template;
let
  executable = haskell-web-api-template.chakra.components.exes.chakra-exe;
  binOnly = prj.pkgs.runCommand "haskell-web-api-template-bin" { } ''
    mkdir -p $out/bin
    cp ${executable}/bin/chakra-exe $out/bin
    ${nativePkgs.nukeReferences}/bin/nuke-refs $out/bin/chakra-exe
  '';
in { 
  haskell-web-api-template-image = prj.pkgs.dockerTools.buildImage {
  name = "haskell-web-api-template";
  tag = executable.version;
  contents = [ binOnly prj.pkgs.cacert prj.pkgs.iana-etc ];
  config.Entrypoint = "chakra-exe";
  config.Cmd = "";
  };
}) crossBuildProject
