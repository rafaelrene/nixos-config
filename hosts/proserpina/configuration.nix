{ config, inputs, ... }:
let
  modules = config.flake.modules.darwin;
in
{
  flake.darwinConfigurations.Proserpina = inputs.nix-darwin.lib.darwinSystem {
    modules = [ modules.proserpina ];
  };
  flake.modules.darwin.proserpina =
    { config, ... }:
    {
      imports = [
        modules.workstation
        modules.system
        modules.fonts
        modules.user-files
        modules.updates
        modules.common-applications
        modules.anytype
        modules.discord
        modules.ente
        modules.ente-auth
        modules.filen
        modules.freetube
        modules.gifox
        modules.google-drive
        modules.mailspring
        modules.microsoft-teams
        modules.omniwm
        modules.onlyoffice
        modules.orbstack
        modules.proton-drive
        modules.proton-pass
        modules.raycast
        modules.rustdesk
        modules.shottr
        modules.signal
        modules.skhd
        modules.slack
        modules.standard-notes
        modules.superwhisper
        modules.telegram
        modules.thaw
        modules.ungoogled-chromium
        modules.viber
        modules.whatsapp
        modules.yaak
        modules.zentty
      ];

      nixpkgs.hostPlatform = "aarch64-darwin";
      system = {
        stateVersion = 6;
        primaryUser = config.workstation.user;
      };
      users.users.rafael.home = "/Users/rafael";
      users.users.rafael.openssh.authorizedKeys.keyFiles = [
        ../../modules/applications/openssh/proserpina.pub
      ];
      networking = {
        hostName = "Proserpina";
        localHostName = "Proserpina";
        computerName = "Proserpina";
      };
      workstation = {
        user = "rafael";
        codeRoot = "/Users/rafael/code";
        checkout = "/Users/rafael/code/.personal/nixos-config";
        links.".local/share/codex/config.toml" =
          "${config.workstation.checkout}/hosts/proserpina/codex.toml";
        links.".local/share/claude/settings.json" =
          "${config.workstation.checkout}/hosts/proserpina/claude.json";
      };
    };
}
