// Runs in Stylus's manage page, whose API global calls into its background.
// settings.py appends the call to one of these.

// Declared settings: Stylus preferences, and bundles of styles in Stylus's
// backup format to import, with values for their usercss variables.
async function load({ settings, imports }) {
  await API.prefs.set(settings);
  const idsByName = new Map((await API.styles.getAll()).map(style => [style.name.trim(), style.id]));
  const errors = [];
  for (const { url, vars } of imports) {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`${url}: ${response.status}`);
    // Its settings entry has no sourceCode; ours replace it.
    const styles = (await response.json()).filter(item => item.sourceCode);
    for (const style of styles) {
      style.name = style.name.trim();
      // Matched by name like Stylus's import, so loading again updates
      // styles instead of duplicating them.
      style.id = idsByName.get(style.name);
      for (const [name, value] of Object.entries(vars)) {
        const variable = style.usercssData?.vars?.[name];
        if (variable) variable.value = value;
      }
    }
    for (let i = 0; i < styles.length; i += 30) {
      const results = await API.styles.importMany(styles.slice(i, i + 30));
      results.forEach((result, j) => result.err && errors.push(`${styles[i + j].name}: ${result.err}`));
    }
  }
  if (errors.length) throw new Error(errors.join("\n"));
}

// The sites enabled styles apply to, as Dark Reader site list patterns.
async function sites() {
  const escape = string => string.replace(/[\\^$.*+?()[\]{}|/]/g, "\\$&");
  const patterns = new Set();
  for (const style of await API.styles.getAll()) {
    if (!style.enabled) continue;
    for (const { domains = [], urlPrefixes = [], urls = [], regexps = [] } of style.sections) {
      // Stylus's domains include subdomains; Dark Reader's only www.
      for (const domain of domains) patterns.add(domain).add(`*.${domain}`);
      for (const prefix of urlPrefixes) patterns.add(`/^${escape(prefix)}/`);
      for (const url of urls) patterns.add(`/^${escape(url)}$/`);
      // Stylus matches a regexp against the whole URL.
      for (const regexp of regexps) patterns.add(`/^(?:${regexp})$/`);
    }
  }
  return [...patterns].sort();
}
