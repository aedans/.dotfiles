// Runs in Firefox Color's generated background page: it has no pages of its
// own, and its background script only applies the stored theme, so running
// it again there is harmless. settings.py appends the call to one of these.

// The theme as Firefox Color stores it, with any images it was given.
async function dump() {
  return await browser.storage.local.get(["theme", "images"]);
}

// Applied when Firefox Color next starts. firstRunDone stops it opening its
// website on that start.
async function load(settings) {
  await browser.storage.local.set({ ...settings, firstRunDone: true });
}
