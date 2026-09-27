{ lib, ... }:
{
  options.features.coding-agents.links = lib.mkOption {
    type = lib.types.functionTo (lib.types.attrsOf lib.types.raw);
    description = "Declare shared agent rules, settings and skill links.";
  };

  config.features.coding-agents.links =
    {
      lib,
      skillSource ? "skills",
      extraSkills ? { },
    }:
    let
      skillNames = lib.attrNames (
        lib.filterAttrs (
          name: type:
          type == "directory" && builtins.pathExists (../../../config/agents/skills + "/${name}/SKILL.md")
        ) (builtins.readDir ../../../config/agents/skills)
      );
      skillDirectories = [
        ".local/share/codex/skills"
        ".local/share/claude/skills"
        ".config/opencode/skills"
      ];
      skills = lib.genAttrs skillNames (name: "${skillSource}/${name}") // extraSkills;
    in
    {
      inherit skillDirectories;
      rules = {
        ".local/share/codex/AGENTS.md" = "AGENTS.md";
        ".local/share/claude/AGENTS.md" = "AGENTS.md";
        ".local/share/claude/CLAUDE.md" = "CLAUDE.md";
        ".config/opencode/AGENTS.md" = "AGENTS.md";
      };
      settings = {
        ".local/share/claude/settings.json" = "claude/settings.json";
        ".config/opencode/opencode.jsonc" = "opencode/opencode.jsonc";
        ".config/opencode/tui.json" = "opencode/tui.json";
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
