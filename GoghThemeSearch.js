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

if (typeof module !== "undefined") {
  module.exports = {
    parseThemes: parseThemes,
    normalizedQuery: normalizedQuery,
    normalizedVariant: normalizedVariant,
    matchesVariant: matchesVariant,
    filterThemes: filterThemes
  }
}
