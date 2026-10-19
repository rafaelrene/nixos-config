{ config, lib, ... }:
{
  flake.modules = lib.genAttrs [ "nixos" "darwin" ] (platform: {
    cli-tools.imports = with (config.features.modulesFor platform); [
      age
      bat
      bkt
      btop
      curl
      eza
      fd
      fzf
      gnutar
      jq
      lsof
      openssh
      ripgrep
      tealdeer
      unzip
      wget
      xz
      yazi
      yq-go
      zip
    ];
  });
}
