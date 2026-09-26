function parseThemes(raw) {
  try {
    var data = JSON.parse(String(raw || ""))
    return Array.isArray(data) ? data : []
  } catch (e) {
    return []
  }
}

function normalizedQuery(query) {
  return String(query || "").trim().toLowerCase()
}

function normalizedVariant(variant) {
  var v = String(variant || "").trim().toLowerCase()
  return v === "light" ? "light" : (v === "dark" ? "dark" : "")
}

function matchesVariant(item, variantFilter) {
  var wanted = String(variantFilter || "all").trim().toLowerCase()
  if (!wanted || wanted === "all") return true
  return normalizedVariant(item && item.variant) === wanted
}

function searchText(item) {
  return (String((item && item.name) || "") + " " + String((item && item.subtitle) || "")).toLowerCase()
}

function filterThemes(themes, query, variantFilter, limit) {
  var values = Array.isArray(themes) ? themes : []
  var needle = normalizedQuery(query)
  var max = limit === undefined || limit === null ? 600 : Number(limit)
  if (isNaN(max)) max = 600
  max = Math.max(0, max)
  if (max === 0) return []

  var out = []
  for (var i = 0; i < values.length; i++) {
    var item = values[i]
    if (!item || !item.name) continue
    if (!matchesVariant(item, variantFilter)) continue
    if (!needle || searchText(item).indexOf(needle) >= 0) {
      out.push(item)
      if (out.length >= max) break
    }
  }

  return out
}

// Mirrors the slug gogh-theme-install uses for the theme directory name, so
// the active Omarchy theme (current/theme.name) can be mapped back to a Gogh
// theme.
function themeSlug(name) {
  return "gogh-" + String(name || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
}

function findBySlug(themes, slug) {
  var values = Array.isArray(themes) ? themes : []
  if (!slug) return null
  for (var i = 0; i < values.length; i++) {
    if (values[i] && values[i].name && themeSlug(values[i].name) === slug) return values[i]
  }
  return null
}

// Display name for a non-Gogh Omarchy theme dir name, e.g. "tokyo-night" ->
// "Tokyo Night".
function prettyThemeSlug(slug) {
  return String(slug || "").split("-").filter(function(w) { return w.length > 0 })
    .map(function(w) { return w.charAt(0).toUpperCase() + w.slice(1) }).join(" ")
}

if (typeof module !== "undefined") {
  module.exports = {
    parseThemes: parseThemes,
    normalizedQuery: normalizedQuery,
    normalizedVariant: normalizedVariant,
    matchesVariant: matchesVariant,
    filterThemes: filterThemes,
    themeSlug: themeSlug,
    findBySlug: findBySlug,
    prettyThemeSlug: prettyThemeSlug
  }
}
