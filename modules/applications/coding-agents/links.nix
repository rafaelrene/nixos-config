{ config, lib, ... }:
{
  options.features.coding-agents.source = lib.mkOption {
    type = lib.types.path;
    default = ../../../config/agents;
    description = "Shared editable agent instructions, settings, and skills.";
  };

  options.features.coding-agents.links = lib.mkOption {
    type = lib.types.functionTo (lib.types.attrsOf lib.types.raw);
    description = "Declare shared agent rules, settings and skill links.";
  };

  config.features.coding-agents.links =
    {
      lib,
      skillSource ? "skills",
    }:
    let
      skillNames = lib.attrNames (
        lib.filterAttrs (
          name: type:
          type == "directory"
          && builtins.pathExists (config.features.coding-agents.source + "/skills/${name}/SKILL.md")
        ) (builtins.readDir (config.features.coding-agents.source + "/skills"))
      );
      skillDirectories = [
        ".local/share/codex/skills"
        ".local/share/claude/skills"
      ];
      skills = lib.genAttrs skillNames (name: "${skillSource}/${name}");
    in
    {
      inherit skillDirectories;
      rules = {
        ".local/share/codex/AGENTS.md" = "AGENTS.md";
        ".local/share/claude/AGENTS.md" = "AGENTS.md";
        ".local/share/claude/CLAUDE.md" = "CLAUDE.md";
      };
      settings = {
        ".local/share/claude/settings.json" = "claude/settings.json";
      };
      skillLinks = lib.listToAttrs (
        lib.concatMap (
          directory:
          lib.mapAttrsToList (name: value: {
            name = "${directory}/${name}";
            inherit value;
          }) skills
        ) skillDirectories
      );
    };
}
