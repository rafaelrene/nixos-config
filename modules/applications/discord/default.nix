{ inputs, config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.darwin.discord =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      unstable = import inputs.nixpkgs-unstable {
        system = pkgs.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      };
      package = unstable.discord.overrideAttrs (old: {
        # Keep Nixpkgs' staged modules outside Discord's signed resource seal.
        installPhase =
          lib.replaceStrings
            [ "$out/Applications/Discord.app/Contents/Resources/modules" ]
            [ "$out/share/discord-modules" ]
            old.installPhase;
      });
      discordManifest =
        let
          inherit (package) source;
          hostVersion = map lib.toInt (lib.splitString "." source.version);
          artifact = value: {
            host_version = hostVersion;
            package_sha256 = builtins.convertHash {
              inherit (value) hash;
              toHashFormat = "base16";
            };
            inherit (value) url;
          };
        in
        pkgs.writeText "discord-pinned-update.json" (
          builtins.toJSON {
            full = artifact source.distro;
            deltas = [ ];
            modules = lib.mapAttrs (_: value: {
              full = artifact value // {
                module_version = value.version;
              };
              deltas = [ ];
            }) source.modules;
            required_modules = lib.attrNames source.modules;
            metadata_version = 1;
            required_update = true;
          }
        );
      discordUpdateSettings = features.shell.darwinApplication {
        inherit pkgs;
        name = "configure-discord-updates";
        runtimeInputs = [ pkgs.jq ];
        text = ''
          directory="$HOME/Library/Application Support/discord"
          mkdir -p "$directory"
          settings="$directory/settings.json"
          if ! test -e "$settings"; then printf '{}\n' > "$settings"; fi
          temporary=$(mktemp "$directory/settings.XXXXXX")
          trap 'rm -f "$temporary"' EXIT
          jq '.USE_PINNED_UPDATE_MANIFEST = true' "$settings" > "$temporary"
          install -m644 ${discordManifest} "$directory/pinned_update.json"
          mv "$temporary" "$settings"
        '';
      };
    in
    {
      environment.systemPackages = [ package ];
      system.activationScripts.postActivation.text = lib.mkAfter ''
        # The native updater ignores SKIP_HOST_UPDATE. Its pinned manifest keeps
        # Finder launches on Nixpkgs' host/module versions without altering signatures.
        /usr/bin/sudo -H -u ${lib.escapeShellArg config.system.primaryUser} -- ${lib.getExe discordUpdateSettings}
      '';
    };
}
