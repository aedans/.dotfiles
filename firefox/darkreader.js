// Runs in Dark Reader's popup page, which talks to its background with these
// messages. settings.py appends the call to one of these.

const send = (type, data) => browser.runtime.sendMessage({ type, data });

// Settings in Dark Reader's export format, less when it was installed.
async function dump() {
  const { installation, ...settings } = (await send("ui-bg-get-data")).data.settings;
  return settings;
}

async function load(settings) {
  // Kept in local storage: the dotfiles sync them, and Firefox's sync
  // storage can't hold a long site list, which Dark Reader only splits
  // across items in Chrome.
  await send("ui-bg-change-settings", { ...settings, syncSettings: false });
  // Dark Reader saves a second after a change, so wait for the settings it
  // keeps (it drops invalid site patterns) to reach storage before Firefox
  // quits.
  const { data } = await send("ui-bg-get-data");
  const keys = Object.keys(data.settings);
  const expected = JSON.stringify(data.settings);
  for (const deadline = Date.now() + 60_000; Date.now() < deadline; ) {
    const stored = await browser.storage.local.get(keys);
    if (JSON.stringify(Object.fromEntries(keys.map(key => [key, stored[key]]))) === expected) return;
    await new Promise(resolve => setTimeout(resolve, 500));
  }
  throw new Error("Dark Reader didn't save its settings");
}
