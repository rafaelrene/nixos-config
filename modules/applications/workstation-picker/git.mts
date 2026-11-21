import { spawnSync } from "node:child_process";
import { lstatSync, realpathSync } from "node:fs";
import { homedir } from "node:os";
import { basename, join, resolve } from "node:path";
import { createInterface } from "node:readline";

import {
  labels,
  tags,
  type Branch,
  type LocalBranch,
  type Row,
  type WorktreeBase,
} from "./types.mts";

type Worktree = { path: string; head: string; branch?: string };

export type Repository = {
  root: string;
  main: Worktree;
  current: Worktree;
  worktrees: Worktree[];
  parent?: string;
};

export const maxBuffer = 32 * 1024 * 1024;

function git(directory: string, args: string[]) {
  const result = spawnSync("git", ["-C", directory, ...args], {
    encoding: "utf8",
    maxBuffer,
  });
  if (result.error) throw result.error;
  return result;
}

function gitOutput(directory: string, args: string[]): string {
  const result = git(directory, args);
  if (result.status === 0) return result.stdout;
  throw new Error(result.stderr.trim() || `git ${args[0]} failed.`);
}

function gitPath(directory: string, args: string[]): string | undefined {
  const result = git(directory, ["rev-parse", ...args]);
  const path = result.stdout.replace(/\n$/, "");
  if (result.status === 0 && path) return path;
}

function canonicalPath(path: string): string {
  try {
    return realpathSync(path);
  } catch {
    return resolve(path);
  }
}

export function repositoryRoot(directory: string): string | undefined {
  const root = gitPath(directory, ["--show-toplevel"]);
  if (root) return canonicalPath(root);
}

function listWorktrees(root: string): Worktree[] {
  const records = gitOutput(root, ["worktree", "list", "--porcelain", "-z"]);
  const worktrees: Worktree[] = [];

  for (const record of records.split("\0\0")) {
    if (!record) continue;
    const fields = record.split("\0");
    const path = fields[0].slice("worktree ".length);
    const branch = fields.find((field) =>
      field.startsWith("branch refs/heads/"),
    );
    const head = fields.find((field) => field.startsWith("HEAD "));
    if (!path) throw new Error("Git returned a worktree without a path.");
    worktrees.push({
      path: canonicalPath(path),
      branch: branch?.slice("branch refs/heads/".length),
      head: head?.slice("HEAD ".length) ?? "",
    });
  }

  const main = worktrees[0];
  if (!main) throw new Error("Git returned an empty worktree list.");
  // Submodules can report the Git directory as the primary worktree.
  if (repositoryRoot(main.path) !== main.path) {
    const commonDir = gitPath(root, [
      "--path-format=absolute",
      "--git-common-dir",
    ]);
    if (commonDir) {
      const configured = git(commonDir, ["config", "--get", "core.worktree"]);
      if (configured.status === 0) {
        main.path = canonicalPath(
          resolve(commonDir, configured.stdout.replace(/\n$/, "")),
        );
      }
    }
  }
  return worktrees;
}

export function findRepository(root: string): Repository {
  const worktrees = listWorktrees(root);
  const main = worktrees[0];
  const current = worktrees.find((tree) => tree.path === root);
  if (!current)
    throw new Error(
      "The current directory is missing from Git's worktree list.",
    );
  const parent =
    gitPath(root, ["--show-superproject-working-tree"]) ??
    (main.path === root
      ? undefined
      : gitPath(main.path, ["--show-superproject-working-tree"]));
  return { root, main, current, worktrees, parent };
}

function localBranches(root: string): LocalBranch[] {
  return gitOutput(root, [
    "for-each-ref",
    "--format=%(refname:strip=2)%09%(upstream)",
    "refs/heads/",
  ])
    .trimEnd()
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const [name, upstream = ""] = line.split("\t");
      return { name, upstream };
    });
}

function worktreeBase(worktree: Worktree): WorktreeBase {
  return {
    ref: worktree.branch ? `refs/heads/${worktree.branch}` : worktree.head,
  };
}

function describeWorktree(worktree: Worktree): string {
  return worktree.branch ?? worktree.head.slice(0, 8);
}

export function repositoryRows(repo: Repository): Row[] {
  const { root, main, current, worktrees, parent } = repo;
  const rows: Row[] = [
    {
      tag: tags.gitDirectories,
      label:
        root === main.path
          ? `${labels.checkout} / ${labels.root}`
          : labels.checkout,
      detail: `${main.path} · ${describeWorktree(main)}`,
      action: { kind: "directory", path: main.path },
      worktree: worktreeBase(main),
    },
  ];
  if (root !== main.path) {
    rows.unshift({
      tag: tags.gitDirectories,
      label: labels.root,
      detail: `${root} · ${describeWorktree(current)}`,
      action: { kind: "directory", path: root },
      worktree: worktreeBase(current),
    });
  }
  if (parent) {
    rows.push({
      tag: tags.gitDirectories,
      label: labels.parent,
      detail: parent,
      action: { kind: "directory", path: parent },
    });
  }

  const owned = new Map(
    worktrees.flatMap((tree) =>
      tree.branch ? [[tree.branch, tree] as const] : [],
    ),
  );
  for (const { name } of localBranches(root)) {
    const tree = owned.get(name);
    if (tree?.path === root || tree?.path === main.path) continue;
    rows.push({
      tag: tree ? tags.gitDirectories : tags.git,
      label: name,
      detail: tree?.path ?? "switch branch in main checkout",
      action: { kind: "branch", branch: { name } },
      worktree: { ref: `refs/heads/${name}` },
    });
  }
  for (const tree of worktrees) {
    if (tree.branch || tree.path === root || tree.path === main.path) continue;
    rows.push({
      tag: tags.gitDirectories,
      label: `${basename(tree.path)} @ ${describeWorktree(tree)}`,
      detail: tree.path,
      action: { kind: "directory", path: tree.path },
      worktree: worktreeBase(tree),
    });
  }

  const remotes = gitOutput(root, [
    "for-each-ref",
    "--format=%(refname)%09%(refname:strip=3)%09%(symref)",
    "refs/remotes/",
  ]);
  for (const line of remotes.trimEnd().split("\n").filter(Boolean)) {
    const [remote, name, symbolic] = line.split("\t");
    if (symbolic) continue;
    rows.push({
      tag: tags.git,
      label: remote.slice("refs/remotes/".length),
      detail: "remote branch",
      action: { kind: "branch", branch: { name, remote } },
      worktree: { ref: remote, track: true },
    });
  }

  const submodules = new Set(
    gitOutput(root, ["ls-files", "--stage", "-z"])
      .split("\0")
      .filter((record) => record.startsWith("160000 "))
      .map((record) => record.slice(record.indexOf("\t") + 1)),
  );
  for (const submodule of submodules) {
    const path = join(root, submodule);
    rows.push({
      tag: tags.gitDirectories,
      label: `${labels.submodule} ${submodule}`,
      detail: path,
      action: { kind: "directory", path, submodule: true },
    });
  }

  rows.push(
    {
      tag: tags.manage,
      label: "Create worktree…",
      detail: `from ${describeWorktree(current)}`,
      action: { kind: "create", from: { ref: current.head } },
    },
    {
      tag: tags.manage,
      label: "Manage branches and worktrees…",
      detail: "review and delete",
      action: { kind: "delete" },
    },
  );
  return rows;
}

export function openBranch(repo: Repository, branch: Branch): string {
  const { root, main } = repo;
  let { name, remote } = branch;
  if (remote) {
    const locals = localBranches(root);
    const tracked = locals.filter((local) => local.upstream === remote);
    const match = tracked.find((local) => local.name === name) ?? tracked[0];
    if (match) {
      name = match.name;
      remote = undefined;
    } else if (locals.some((local) => local.name === name)) {
      throw new Error(
        `Local branch ${name} does not track ${remote}. Use Ctrl+W to create a worktree with a new branch name.`,
      );
    }
  }

  const owner = listWorktrees(root).find((tree) => tree.branch === name);
  if (owner) return owner.path;

  gitOutput(
    main.path,
    remote
      ? ["switch", "--track", "-c", name, "--", remote]
      : ["switch", "--no-guess", "--", name],
  );
  return main.path;
}

export async function createWorktree(
  repo: Repository,
  from: WorktreeBase,
): Promise<string | undefined> {
  if (!from.ref || /^0+$/.test(from.ref)) {
    throw new Error("Commit before creating a worktree.");
  }
  const directory = join(
    process.env.T3CODE_HOME || join(homedir(), ".local/share/t3code"),
    "worktrees",
    basename(repo.main.path),
  );
  const input = createInterface({
    input: process.stdin,
    output: process.stderr,
  });
  const name = await new Promise<string>((resolve) => {
    input.once("close", () => resolve(""));
    input.question(
      `New worktree in ${directory} from ${from.ref}\nWorktree / branch name (empty cancels): `,
      resolve,
    );
  }).finally(() => input.close());
  const branch = name.trim();
  if (!branch) return;
  if (
    gitOutput(repo.root, ["check-ref-format", "--branch", branch]).trimEnd() !==
    branch
  ) {
    throw new Error("Enter a literal branch name.");
  }

  const target = join(directory, branch.replaceAll("/", "-"));
  if (lstatSync(target, { throwIfNoEntry: false })) {
    throw new Error(`Worktree path already exists: ${target}`);
  }
  const options = from.track ? ["--track"] : [];
  gitOutput(repo.main.path, [
    "worktree",
    "add",
    ...options,
    "-b",
    branch,
    "--",
    target,
    from.ref,
  ]);
  return target;
}
