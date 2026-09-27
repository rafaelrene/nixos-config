{ inputs, ... }:
{
  flake.modules.darwin.rustdesk = { lib, pkgs, ... }: {
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
