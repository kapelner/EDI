# Proposed static check (v1.0.6-TODO-106): flag assertNumeric/assertNumber/assertIntegerish
# calls that leave checkmate's permissive defaults implicit.
#   assertNumeric/assertIntegerish: must name any.missing; assertNumeric must also name finite or both lower and upper.
#   assertNumber: must name finite or both lower and upper.
# A call can opt out with a trailing comment "# checkmate-loose: <why>" on the line before.
files = list.files("R/EDI/R", pattern = "\\.R$", full.names = TRUE)
bad = character()
for (f in files) {
  pd = getParseData(parse(f, keep.source = TRUE))
  src = readLines(f)
  hits = pd[pd$token == "SYMBOL_FUNCTION_CALL" & pd$text %in% c("assertNumeric", "assertNumber", "assertIntegerish"), ]
  for (i in seq_len(nrow(hits))) {
    call_id = pd$parent[pd$id == hits$parent[i]]
    kids = pd[pd$parent == call_id, ]
    named = kids$text[kids$token == "SYMBOL_SUB"]
    fn = hits$text[i]; ln = hits$line1[i]
    if (ln > 1 && grepl("checkmate-loose:", src[ln - 1])) next
    bounded = all(c("lower", "upper") %in% named)
    need = character()
    if (fn %in% c("assertNumeric", "assertIntegerish") && !"any.missing" %in% named) need = c(need, "any.missing")
    if (fn %in% c("assertNumeric", "assertNumber") && !"finite" %in% named && !bounded) need = c(need, "finite (or lower+upper)")
    if (length(need)) bad = c(bad, sprintf("%s:%d %s needs %s", basename(f), ln, fn, paste(need, collapse = ", ")))
  }
}
cat(bad, sep = "\n"); cat(length(bad), "flagged\n")
