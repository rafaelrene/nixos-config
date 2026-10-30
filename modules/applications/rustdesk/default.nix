{ inputs, config, ... }:
{
  flake.modules.darwin.rustdesk = { lib, pkgs, ... }: {
    # User preferences do not disable an updater already enabled in a root service.
    imports = [
      (config.features.updates.darwinAppSettings {
        process = "RustDesk";
        directory = "Library/Preferences/com.carriez.RustDesk";
        files = {
          "RustDesk_local.toml" = {
            format = "toml";
            settings.options.enable-check-update = "N";
          };
          "RustDesk2.toml" = {
            format = "toml";
            settings.options.allow-auto-update = "N";
          };
        };
      })
    ];
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.rustdesk.overrideAttrs {
        dontFixup = true;
      })
    ];
    system.activationScripts = {
      # Reject unmanaged vendor paths before activation changes applications.
      preActivation.text = lib.mkBefore ''
        destination="/Applications/RustDesk.app"
        target="/Applications/Nix Apps/RustDesk.app"
        if test -L "$destination" && test "$(readlink "$destination")" = "$target"; then
          :
        elif test -e "$destination" || test -L "$destination"; then
          echo "Refusing to replace unmanaged application: $destination" >&2
          exit 1
        fi
      '';
      postActivation.text = lib.mkAfter ''
        # Upstream helpers use this fixed path. Keep just one actual app bundle.
        destination="/Applications/RustDesk.app"
        target="/Applications/Nix Apps/RustDesk.app"
        if test -L "$destination" && test "$(readlink "$destination")" = "$target"; then
          :
        elif test -e "$destination" || test -L "$destination"; then
          echo "Refusing to replace unmanaged application: $destination" >&2
          exit 1
        else
          ln -s "$target" "$destination"
        fi
      '';
    };
  };
}
