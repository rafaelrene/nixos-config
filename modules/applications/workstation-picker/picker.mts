import { spawnSync } from "node:child_process";
import { realpathSync } from "node:fs";

import {
  createWorktree,
  findRepository,
  maxBuffer,
  openBranch,
  repositoryRoot,
  repositoryRows,
  type Repository,
} from "./git.mts";
import {
  checkManager,
  destinations,
  displayPath,
  scriptRows,
} from "./projects.mts";
import { labels, tags, type Route, type Row } from "./types.mts";

const primaryLabels = {
  directory: "cd",
  branch: "go / switch",
  script: "run",
  ssh: "connect",
  create: "create worktree",
  delete: "review deletion",
};

function clean(text: string): string {
  return text.replace(/[\p{Cc}\p{Cf}]/gu, " ");
}

function prefix(text: string): string {
  return "^" + text.replaceAll(" ", "\\ ");
}

const queryFilter = `
case "$FZF_QUERY" in
  '##'*) printf '%s %s\\n' '${prefix(tags.manage)}' "\${FZF_QUERY#??}" ;;
  '#checkout') printf '%s\\n' '${prefix(tags.gitDirectories + " " + labels.checkout)}' ;;
  '#parent') printf '%s\\n' '${prefix(tags.gitDirectories + " " + labels.parent)}' ;;
  '#root') printf '%s\\n' '${prefix(tags.gitDirectories + " " + labels.root)} | ${prefix(tags.gitDirectories + " " + labels.checkout + " / " + labels.root)}' ;;
  '#sub'|'#sub '*) printf '%s %s\\n' '${prefix(tags.gitDirectories + " " + labels.submodule + " ")}' "\${FZF_QUERY#????}" ;;
  '@home') printf '%s\\n' '${prefix(tags.directories + " " + labels.home + "  ·")}' ;;
  '@code') printf '%s\\n' '${prefix(tags.directories + " " + labels.code + "  ·")}' ;;
  '@config') printf '%s\\n' '${prefix(tags.directories + " " + labels.config + "  ·")}' ;;
  '#'*) printf '%s %s\\n' '${prefix(tags.git)} | ${prefix(tags.manage)}' "\${FZF_QUERY#?}" ;;
  @*) printf '%s %s\\n' '${prefix(tags.directories)} | ${prefix(tags.gitDirectories)}' "\${FZF_QUERY#?}" ;;
  :*) printf '%s %s\\n' '${prefix(tags.scripts)}' "\${FZF_QUERY#?}" ;;
  *) printf '%s\\n' "$FZF_QUERY" ;;
esac`;

function choose(rows: Row[], cwd: string, query: string) {
  const header = [
    clean(displayPath(cwd)),
    "[@] destinations   [:] scripts   [#] Git   [##] manage   Esc close",
    "@home   @code   @config   #checkout   #parent   #root   #sub <name>",
    "Ctrl+W create worktree   Ctrl+T new window   Ctrl+E edit script",
  ].join("\n");
  const input = rows
    .map((row, index) => {
      const isRoute =
        row.action.kind === "directory" || row.action.kind === "branch";
      const isScript = row.action.kind === "script";
      const flags =
        ((isRoute && "w") || "") +
        ((row.worktree && "b") || "") +
        ((isScript && "e") || "");
      const footer = [
        `Enter ${primaryLabels[row.action.kind]}`,
        isRoute && "Ctrl+T new window",
        row.worktree && "Ctrl+W create worktree",
        isScript && "Ctrl+E edit command",
      ]
        .filter(Boolean)
        .join(" · ");
      return (
        [
          index,
          row.tag,
          clean(row.label),
          clean(row.detail),
          flags || "-",
          footer,
        ].join("\t") + "\0"
      );
    })
    .join("");

  const result = spawnSync(
    "fzf",
    [
      "--with-shell",
      "sh -c",
      "--read0",
      "--print0",
      "--sync",
      "--layout",
      "reverse",
      "--height",
      "~65%",
      "--border",
      "rounded",
      "--info",
      "inline-right",
      "--no-multi",
      "--no-select-1",
      "--no-exit-0",
      "--delimiter",
      "\t",
      "--with-nth",
      "{2} {3}  ·  {4}",
      "--accept-nth",
      "1",
      "--prompt",
      "Pick > ",
      "--header",
      header,
      "--query",
      query,
      "--footer",
      "Enter choose",
      "--bind",
      `start,change:transform-search:${queryFilter}`,
      "--bind",
      "focus:transform-footer:printf '%s' {6}",
      "--bind",
      "enter:print(enter)+accept",
      "--bind",
      'ctrl-t:transform:case {5} in *w*) echo "print(window)+accept";; esac',
      "--bind",
      'ctrl-w:transform:case {5} in *b*) echo "print(worktree)+accept";; *) echo unix-word-rubout;; esac',
      "--bind",
      'ctrl-e:transform:case {5} in *e*) echo "print(edit)+accept";; *) echo end-of-line;; esac',
    ],
    { encoding: "utf8", stdio: ["pipe", "pipe", "inherit"], input, maxBuffer },
  );
  if (result.error) throw result.error;
  if (
    result.status === 1 ||
    result.status === 130 ||
    result.signal === "SIGINT"
  )
    return;
  if (result.status !== 0)
    throw new Error(`fzf failed (${result.signal ?? result.status}).`);
  const [key, selected] = result.stdout.split("\0");
  if (!/^\d+$/.test(selected ?? "")) return;
  const row = rows[Number(selected)];
  if (row) return { key, row };
}

function inTerminal(command: string, args: string[]) {
  const result = spawnSync(command, args, { stdio: ["inherit", 2, 2] });
  if (result.error) throw result.error;
  if (result.status !== 0 && result.signal !== "SIGINT")
    process.exitCode = result.status ?? 1;
}

function newWindow(path: string) {
  if (process.platform === "darwin") {
    const terminal = process.env.TERMINAL;
    if (terminal) inTerminal(terminal, [path]);
    else
      inTerminal("/usr/bin/open", [
        "-na",
        "Ghostty",
        "--args",
        `--working-directory=${path}`,
        "--window-save-state=never",
      ]);
  } else {
    inTerminal("ghostty", ["+new-window", `--working-directory=${path}`]);
  }
}

function sendToShell(action: "cd" | "run" | "edit", ...args: string[]) {
  process.stdout.write([action, ...args, ""].join("\0"));
}

function routePath(route: Route, repo: Repository | undefined): string {
  if (route.kind === "branch") {
    if (!repo)
      throw new Error("A Git repository is required to switch branches.");
    return openBranch(repo, route.branch);
  }
  if (route.submodule && repositoryRoot(route.path) !== route.path) {
    throw new Error(
      `Initialize the submodule before navigating to it: ${displayPath(route.path)}`,
    );
  }
  return realpathSync(route.path);
}

async function main() {
  const [deletionReview, code, query = ""] = process.argv.slice(2);
  if (!code || !deletionReview)
    throw new Error("Use the Zsh pick command to open the workstation picker.");
  const cwd = realpathSync(process.cwd());
  const root = repositoryRoot(cwd);
  const repo = root ? findRepository(root) : undefined;
  const gitRows = repo ? repositoryRows(repo) : [];
  const scripts = scriptRows(cwd, root);
  const knownPaths = new Set(
    gitRows.flatMap(({ action }) =>
      action.kind === "directory" ? [action.path] : [],
    ),
  );
  const places = destinations(code, knownPaths);
  const selection = choose([...gitRows, ...scripts, ...places], cwd, query);
  if (!selection) return;

  const { key, row } = selection;
  const { action } = row;
  if (key === "worktree" || action.kind === "create") {
    const from =
      key === "worktree"
        ? row.worktree
        : action.kind === "create"
          ? action.from
          : undefined;
    if (repo && from) {
      const path = await createWorktree(repo, from);
      if (path) sendToShell("cd", path);
    }
    return;
  }
  switch (action.kind) {
    case "directory":
    case "branch": {
      const path = routePath(action, repo);
      if (key === "window") newWindow(path);
      else sendToShell("cd", path);
      break;
    }
    case "script":
      checkManager(action.manager);
      sendToShell(
        key === "edit" ? "edit" : "run",
        action.directory,
        action.manager,
        action.name,
      );
      break;
    case "ssh":
      inTerminal("ssh", [action.host]);
      break;
    case "delete":
      inTerminal(deletionReview, []);
      break;
  }
}

try {
  await main();
} catch (error) {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
}
