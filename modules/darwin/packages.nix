{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
  casks = inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system};
  vendor = import ./vendor-packages.nix { inherit pkgs; };
  caskNames = [
    "amethyst"
    "anytype"
    "ente"
    "ente-auth"
    "filen"
    "gifox"
    "onlyoffice"
    "proton-drive"
    "rustdesk"
    "signal"
    "slack"
    "standard-notes"
    "superwhisper"
    "telegram"
    "ungoogled-chromium"
    "whatsapp"
  ];
  # These names identify only the Homebrew installations replaced by Nix.
  applications = lib.genAttrs caskNames (name: casks.${name}.overrideAttrs { dontFixup = true; }) // {
    inherit (unstable)
      iina
      mailspring
      orbstack
      shottr
      yaak
      ;
    # Raycast 2.4 cannot open databases already migrated by 2.5.2.
    raycast =
      if lib.versionAtLeast unstable.raycast.version "2.5.2.0" then
        unstable.raycast
      else
        unstable.raycast.overrideAttrs {
          version = "2.5.2.0";
          src = pkgs.fetchurl {
            name = "Raycast.dmg";
            url = "https://x-r2.raycast-releases.com/Raycast_2.5.2.0_67ef5b0f31_arm64.dmg";
            hash = "sha256-G3l4Ng0blsqWsL8T2bHRlAWZzuxh3YyFoN4/DoJEWyM=";
          };
        };
    discord = unstable.discord.overrideAttrs (old: {
      # Keep Nixpkgs' staged modules outside Discord's signed resource seal.
      installPhase =
        lib.replaceStrings
          [ "$out/Applications/Discord.app/Contents/Resources/modules" ]
          [ "$out/share/discord-modules" ]
          old.installPhase;
    });
    proton-pass = unstable.proton-pass.overrideAttrs { dontFixup = true; };
    # macOS 27 support currently ships on Thaw's alpha channel.
    thaw = casks.thaw.overrideAttrs {
      version = "3.0.0-alpha.7";
      src = pkgs.fetchurl {
        url = "https://github.com/thaw-app/Thaw/releases/download/3.0.0-alpha.7/Thaw_3.0.0-alpha.7.zip";
        hash = "sha256-dANNgipCGnQwQgzb3Ir6LUPhQZ7jZLZO42h9DBqNDfE=";
      };
      dontFixup = true;
    };
    ghostty = pkgs.ghostty-bin;
    inherit (vendor) google-drive viber;
    tailscale-app = casks.tailscale-app.overrideAttrs (old: {
      dontFixup = true;
      # The installed app path exists only after activation.
      installPhase = old.installPhase + ''
        mkdir -p "$out/bin"
        makeWrapper /usr/bin/env "$out/bin/tailscale" \
          --set TAILSCALE_BE_CLI 1 \
          --add-flag '/Applications/Nix Apps/Tailscale.app/Contents/MacOS/Tailscale'
      '';
    });
    zentty = casks.zentty.overrideAttrs (old: {
      dontFixup = true;
      installPhase = old.installPhase + ''
        rm -f "$out/bin/zentty"
        ln -s "$out/Applications/Zentty.app/Contents/Resources/bin/shared/zentty" "$out/bin/zentty"
      '';
    });
    helium-browser = inputs.helium-browser.packages.aarch64-darwin.default.overrideAttrs {
      # The DMG contains a volume directory around the actual application.
      sourceRoot = "Helium/Helium.app";
      dontFixup = true; # Preserve the signed Mac bundle.
    };
    # Use current cask metadata with Nixpkgs' Teams-only payload extraction.
    microsoft-teams = pkgs.teams.overrideAttrs {
      inherit (casks.microsoft-teams) version src;
      dontFixup = true;
    };
    zen = inputs.zen-browser.packages.aarch64-darwin.beta.overrideAttrs (old: {
      # Use nix-darwin's stable app path to keep the browser's install identity.
      installPhase =
        lib.replaceStrings [ "\\$HOME/Applications/Home Manager Apps" ] [ "/Applications/Nix Apps" ]
          old.installPhase;
    });
  };
  tools = {
    graphite = unstable.graphite-cli;
    try-rs = inputs.try-rs.packages.${pkgs.stdenv.hostPlatform.system}.default;
    inherit (unstable) pi-coding-agent;
    git-delta = pkgs.delta;
    jj = pkgs.jujutsu;
    pkgconf = pkgs.pkg-config;
    tree-sitter-cli = pkgs.tree-sitter;
    inherit (pkgs)
      age
      btop
      fd
      fzf
      jq
      lame
      lazygit
      nasm
      nushell
      openssh
      ripgrep
      sops
      sshpass
      starship
      tealdeer
      viu
      wget
      yazi
      ;
  };
  discordManifest =
    let
      source = applications.discord.source;
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
  discordUpdateSettings = pkgs.writeShellApplication {
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
  cleanup = pkgs.writeShellApplication {
    name = "remove-replaced-homebrew-packages";
    runtimeInputs = [ pkgs.gnugrep ];
    text = ''
      if ! test -x /opt/homebrew/bin/brew; then exit 0; fi
      export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_AUTOREMOVE=1
      installedCasks=$(/opt/homebrew/bin/brew list --cask)
      installedFormulae=$(/opt/homebrew/bin/brew list --formula)
      for cask in ${
        lib.escapeShellArgs (
          lib.attrNames applications
          ++ [
            "freetube"
            "t3-code@nightly"
            "font-hack-nerd-font"
            "font-jetbrains-mono"
            "font-jetbrains-mono-nerd-font"
          ]
        )
      }; do
        if grep -Fxq "$cask" <<< "$installedCasks"; then
          echo "Removing Homebrew $cask; its Nix replacement is installed."
          /opt/homebrew/bin/brew uninstall --cask "$cask"
        fi
      done
      # Rolling agents must actually be installed before retiring their old copies.
      for entry in 'codex:codex' 'claude-code@latest:claude'; do
        cask=''${entry%:*}
        command=''${entry#*:}
        if grep -Fxq "$cask" <<< "$installedCasks" && test -x "$HOME/.local/state/nix/profiles/llm-agents/bin/$command"; then
          /opt/homebrew/bin/brew uninstall --cask "$cask"
        fi
      done
      for formula in ${
        lib.escapeShellArgs (
          lib.attrNames tools
          ++ [
            "neovim"
            "opencode"
          ]
        )
      }; do
        if grep -Fxq "$formula" <<< "$installedFormulae"; then
          if test "$formula" = opencode && ! test -x "$HOME/.local/state/nix/profiles/llm-agents/bin/opencode"; then continue; fi
          dependents=$(/opt/homebrew/bin/brew uses --installed "$formula")
          if test -n "$dependents"; then
            echo "Keeping Homebrew $formula for installed dependents: $dependents"
            continue
          fi
          echo "Removing Homebrew $formula; its Nix replacement is installed."
          /opt/homebrew/bin/brew uninstall --formula "$formula"
        fi
      done
    '';
  };
in
{
  options.workstation.removeReplacedHomebrewPackages = lib.mkEnableOption "remove migrated Homebrew packages and apply vendor app integration after validation";

  config = {
    # Keep project shells and the agent wrappers on the same current Devenv.
    nixpkgs.overlays = [ (_final: _prev: { inherit (unstable) devenv; }) ];

    environment.systemPackages =
      (with pkgs; [
        bat
        curl
        eza
        freetube
        gh
        git
        gnutar
        lsof
        xz
        yq-go
        zip
        unzip
        zoxide
      ])
      ++ lib.attrValues applications
      ++ lib.attrValues tools;

    fonts.packages = with pkgs; [
      nerd-fonts.hack
      nerd-fonts.jetbrains-mono
      jetbrains-mono
    ];

    homebrew.enable = false;

    system = {
      activationScripts = {
        # Check fixed vendor paths before any application copies or Brew removals.
        preActivation.text = lib.mkIf config.workstation.removeReplacedHomebrewPackages (
          lib.mkBefore ''
            installedCasks=""
            if test -x /opt/homebrew/bin/brew; then
              installedCasks=$(/usr/bin/sudo -H -u ${lib.escapeShellArg config.system.primaryUser} -- \
                /usr/bin/env HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 /opt/homebrew/bin/brew list --cask)
            fi
            for entry in 'Google Drive:google-drive' 'RustDesk:rustdesk'; do
              app=''${entry%:*}
              cask=''${entry#*:}
              destination="/Applications/$app.app"
              target="/Applications/Nix Apps/$app.app"
              if test -L "$destination" && test "$(readlink "$destination")" = "$target"; then
                continue
              fi
              if test -e "$destination" || test -L "$destination"; then
                if ! test -L "$destination" && test -d "$destination" && ${lib.getExe pkgs.gnugrep} -Fxq "$cask" <<< "$installedCasks"; then
                  continue
                fi
                echo "Refusing to replace unmanaged application before migration: $destination" >&2
                exit 1
              fi
            done
          ''
        );

        # Remove only known replacements, without --zap or a global Brew cleanup.
        # nix-darwin copies real bundles into /Applications/Nix Apps before cleanup.
        postActivation.text = lib.mkIf config.workstation.removeReplacedHomebrewPackages (
          lib.mkAfter ''
            /usr/bin/sudo -H -u ${lib.escapeShellArg config.system.primaryUser} -- ${lib.getExe cleanup}
            # The native updater ignores SKIP_HOST_UPDATE. Its pinned manifest keeps
            # Finder launches on Nixpkgs' host/module versions without altering signatures.
            /usr/bin/sudo -H -u ${lib.escapeShellArg config.system.primaryUser} -- ${lib.getExe discordUpdateSettings}
            # Upstream helpers use these fixed paths. Keep just one actual app bundle.
            for app in 'Google Drive' RustDesk; do
              destination="/Applications/$app.app"
              target="/Applications/Nix Apps/$app.app"
              if test -L "$destination" && test "$(readlink "$destination")" = "$target"; then
                continue
              fi
              if test -e "$destination" || test -L "$destination"; then
                echo "Refusing to replace unmanaged application: $destination" >&2
                exit 1
              fi
              ln -s "$target" "$destination"
            done
            # Match the vendor installer's mount-helper permissions, outside the store.
            chown root:wheel '/Applications/Nix Apps/Google Drive.app/Contents/MacOS/mount_helper'
            chmod 4755 '/Applications/Nix Apps/Google Drive.app/Contents/MacOS/mount_helper'
            # Merge only Drive's update policy; retain policies for other Google apps.
            (
              set -eu
              policy=$(mktemp)
              trap 'rm -f "$policy" "$policy.json"' EXIT
              domain=/Library/Preferences/com.google.Keystone
              if test -f "$domain.plist"; then
                /usr/bin/defaults export "$domain" - | /usr/bin/plutil -convert json -o "$policy.json" -
              else
                echo '{}' > "$policy.json"
              fi
              ${lib.getExe pkgs.jq} '.updatePolicies["com.google.drivefs"].UpdateDefault = 3' "$policy.json" > "$policy"
              /usr/bin/plutil -convert xml1 "$policy"
              /usr/bin/defaults import "$domain" "$policy"
            )
          ''
        );

      };

      defaults = lib.mkIf config.workstation.removeReplacedHomebrewPackages {
        # Slack checks enforced policy; an ordinary user preference is ignored.
        # nix-darwin inserts custom domains into shell commands without quoting.
        CustomSystemPreferences.${lib.escapeShellArg "/Library/Managed Preferences/com.tinyspeck.slackmacgap"}.AutoUpdate =
          false;
        CustomUserPreferences =
          lib.genAttrs [ "io.tailscale.ipn.macsys" "ch.protonmail.drive" ] (_: {
            SUEnableAutomaticChecks = false;
            SUAutomaticallyUpdate = false;
          })
          // {
            "com.stonerl.Thaw" = {
              UpdateChannel = "alpha";
              AllowsBetaUpdates = true;
              SUEnableAutomaticChecks = false;
              SUAutomaticallyUpdate = false;
            };
          };
      };
    };
  };
}
