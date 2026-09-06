import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { stripTypeScriptTypes } from "node:module";
import test from "node:test";

const source = await readFile(
  new URL("../config/agents/hooks/notification/opencode.ts", import.meta.url),
  "utf8",
);
const javascript = stripTypeScriptTypes(source);
const { NotificationPlugin } = await import(
  `data:text/javascript;base64,${Buffer.from(javascript).toString("base64")}`
);

async function fixture(session) {
  const calls = [];
  const lookups = [];
  const plugin = await NotificationPlugin({
    client: {
      session: {
        get: async (input) => {
          lookups.push(input.path.id);
          if (session instanceof Error) throw session;
          return { data: session };
        },
      },
    },
    $: (strings) => ({
      quiet: () => ({
        nothrow: () => {
          calls.push(strings.join(""));
          return Promise.resolve();
        },
      }),
    }),
  });
  return { plugin, calls, lookups };
}

test("all supported attention events notify for a root session", async () => {
  const { plugin, calls, lookups } = await fixture({ id: "root" });
  for (const type of [
    "session.idle",
    "session.error",
    "permission.asked",
    "question.asked",
  ]) {
    await plugin.event({ event: { type, properties: { sessionID: "root" } } });
  }
  assert.deepEqual(lookups, ["root", "root", "root", "root"]);
  assert.deepEqual(calls, Array(4).fill('"$HOME/.local/bin/agent-notify"'));
});

test("subagent and unrelated events stay silent", async () => {
  const { plugin, calls, lookups } = await fixture({ parentID: "root" });
  await plugin.event({
    event: { type: "session.idle", properties: { sessionID: "child" } },
  });
  await plugin.event({
    event: { type: "message.updated", properties: { sessionID: "root" } },
  });
  assert.deepEqual(lookups, ["child"]);
  assert.deepEqual(calls, []);
});

test("missing session IDs and failed lookups still notify", async () => {
  const { plugin, calls, lookups } = await fixture(new Error("unavailable"));
  await plugin.event({ event: { type: "session.error", properties: {} } });
  await plugin.event({
    event: { type: "session.error", properties: { sessionID: "unknown" } },
  });
  assert.deepEqual(lookups, ["unknown"]);
  assert.equal(calls.length, 2);
});
