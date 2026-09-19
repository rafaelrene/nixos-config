const { chromium } = require(process.env.PLAYWRIGHT_DRIVER);
const { mkdir } = require("node:fs/promises");
const { homedir } = require("node:os");
const { join } = require("node:path");

const pricingUrl =
  "https://chatgpt.com/?default_tab=personal&highlight_plan=pro#pricing";
const topicUrl = "https://ntfy.rafr.dev/pro20x";
const profile = join(
  process.env.XDG_STATE_HOME || join(homedir(), ".local/state"),
  "pro20x-check/browser",
);

async function inspect(page) {
  await page.goto(pricingUrl, {
    waitUntil: "domcontentloaded",
    timeout: 60000,
  });
  await page
    .getByText("Choose your plan", { exact: true })
    .waitFor({ timeout: 30000 });
  // Restrict the match to a control, not marketing text mentioning 20x.
  const tier = page
    .locator('button, [role="radio"], [role="tab"]')
    .filter({ hasText: /^\s*20x\s*$/ });
  await tier.waitFor({ state: "visible", timeout: 15000 });
  if (await tier.isDisabled()) {
    return {
      status: "unavailable",
      message: "Pro 20x is still disabled in your ChatGPT upgrade screen.",
      priority: 3,
    };
  }
  // A trial click checks actionability without selecting a plan or purchasing.
  await tier.click({ trial: true, timeout: 10000 });
  return {
    status: "available",
    message:
      "Pro 20x is now selectable in your ChatGPT upgrade screen. Open ChatGPT to confirm checkout and upgrade.",
    priority: 5,
  };
}

async function notify(result) {
  const checkedAt = new Date().toLocaleString("en-GB", {
    timeZone: "Europe/Bratislava",
  });
  const response = await fetch(topicUrl, {
    method: "POST",
    headers: {
      Title: `ChatGPT Pro 20x: ${result.status}`,
      Priority: String(result.priority),
      Click: pricingUrl,
      "Content-Type": "text/plain; charset=utf-8",
    },
    body: `${result.message}\nChecked: ${checkedAt} (Europe/Bratislava)`,
    signal: AbortSignal.timeout(20000),
  });
  if (!response.ok) throw new Error(`ntfy returned HTTP ${response.status}`);
}

async function main() {
  const args = process.argv.slice(2);
  if (
    args.length > 1 ||
    (args.length === 1 && !["--login", "--dry-run"].includes(args[0]))
  ) {
    throw new Error("Usage: pro20x-check [--login | --dry-run]");
  }
  const login = args[0] === "--login";
  if (login) {
    console.log(
      `Open this link in the browser window launched by this command:\n${pricingUrl}\nSign into ChatGPT, open the upgrade screen, then close that browser to save the session.\nYour usual browser uses a different profile and will not sign the checker in.`,
    );
  }
  let context;
  let result;
  process.umask(0o077);
  try {
    await mkdir(profile, { recursive: true, mode: 0o700 });
    context = await chromium.launchPersistentContext(profile, {
      executablePath: "/run/current-system/sw/bin/helium",
      headless: !login,
      locale: "en-US",
      timeout: 30000,
    });
    const page = context.pages()[0] || (await context.newPage());
    if (login) {
      await new Promise((resolve) => context.once("close", resolve));
      return;
    }
    result = await inspect(page);
  } catch (error) {
    // Do not send page contents, cookies, or browser diagnostics to ntfy.
    console.error(`Browser check failed (${error.name}).`);
    if (login)
      throw new Error(
        "Login browser failed to open or load ChatGPT. Run --login from the Othinus desktop.",
      );
    result = {
      status: "check failed",
      message:
        "Could not determine Pro 20x availability. Login may have expired, ChatGPT may be blocking automation, the page may have changed, or the login browser may still be open. Run pro20x-check --login on Othinus, close it, then run pro20x-check --dry-run.",
      priority: 3,
    };
  } finally {
    await context?.close().catch(() => {});
  }
  console.log(`${result.status}: ${result.message}`);
  if (args[0] !== "--dry-run") await notify(result);
  if (result.status === "check failed") process.exitCode = 1;
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

module.exports = { inspect };
