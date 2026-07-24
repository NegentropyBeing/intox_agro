# -----------------------------------------------------------------------------
# Validate DATA_DICTIONARY.md against the actual parquet files
#
#   Rscript Scripts/validate_data_dictionary.R
#
# The dictionary was originally written from the DATASUS documentation rather
# than from the files this pipeline produces, which is why several fields were
# described as raw codes when `microdatasus` stores them decoded. This script
# exists so that mismatch is caught in one pass instead of surfacing one field
# at a time.
#
# It parses every "**File:**" declaration and every documented variable row,
# then reports three things per file:
#
#   [CODE vs LABEL]  the description claims a code mapping, but the column
#                    holds decoded labels (the COD_IDADE / SEXO / RACACOR class
#                    of error). This must always come back empty.
#   [DOC, NO DATA]   a documented variable that does not exist in the file
#   [DATA, NO DOC]   a column in the file that the dictionary never mentions
#
# Not every hit is a defect. Sections that declare themselves partial, and
# sections that document a naming *pattern* rather than column names, will
# always report [DATA, NO DOC] or [DOC, NO DATA] by design:
#   - Section 1 is a summary; DATA_DICTIONARY_BASE.md holds the full list
#   - Section 3 (SINAN) lists "key analytical variables" only
#   - Section 7 documents the n_estab_<category> / valor_<category> pattern
#   - Section 8.2 documents the <usegroup>_<guidance> pattern
# Read a hit as a question, not a verdict.
# -----------------------------------------------------------------------------

suppressMessages({library(arrow); library(dplyr)})

dict <- "documentos_para_script/DATA_DICTIONARY.md"
md   <- readLines(dict, warn = FALSE)

cur <- NA_character_; rows <- list()
for (i in seq_along(md)) {
  l <- md[i]
  m <- regmatches(l, regexpr("\\*\\*File:\\*\\* `[^`]+`", l))
  if (length(m)) cur <- sub(".*?`([^`]+)`.*", "\\1", m)
  h <- regmatches(l, regexpr("^### [0-9.]+ `[^`]+\\.parquet`", l))
  if (length(h)) cur <- file.path("resultados/PROD_AGRO", sub(".*?`([^`]+)`.*", "\\1", h))
  if (!is.na(cur) && grepl("^\\| `[^`]+` \\|", l)) {
    rows[[length(rows) + 1]] <- data.frame(
      file = cur, var = sub("^\\| `([^`]+)`.*$", "\\1", l), line = i, desc = l)
  }
}
doc <- bind_rows(rows)
doc$file <- sub("CAGED_YYYY_MM\\.parquet", "CAGED_2022_01.parquet", doc$file)

cat(nrow(doc), "documented fields across", length(unique(doc$file)), "files\n\n")

missing_files <- c(); issues <- 0
for (f in unique(doc$file)) {
  if (!file.exists(f)) { missing_files <- c(missing_files, f); next }
  d <- tryCatch(read_parquet(f), error = function(e) NULL)
  if (is.null(d)) { missing_files <- c(missing_files, f); next }
  if (nrow(d) > 3e5) d <- d[sample(nrow(d), 3e5), , drop = FALSE]

  sub    <- doc[doc$file == f, ]
  absent <- setdiff(sub$var, names(d))
  extra  <- setdiff(names(d), sub$var)

  decoded <- c()
  for (k in seq_len(nrow(sub))) {
    v <- sub$var[k]
    if (!v %in% names(d)) next
    x <- d[[v]]
    if (!is.character(x)) next
    vals <- unique(x[!is.na(x)])
    if (!length(vals)) next
    looks_labelled <- mean(grepl("[A-Za-zÀ-ÿ]", vals)) > 0.5 && length(vals) <= 30
    claims_codes   <- grepl("`[0-9]{1,2}`\\s*=|`0[0-9]`|\\(coded\\)|coded per|coding\\)", sub$desc[k])
    if (looks_labelled && claims_codes)
      decoded <- c(decoded, sprintf("%s (line %d) holds: %s", v, sub$line[k],
                                    paste(head(sort(vals), 6), collapse = ", ")))
  }

  if (length(absent) || length(extra) || length(decoded)) {
    issues <- issues + 1
    cat("###", f, sprintf("(%d documented / %d columns)\n", nrow(sub), ncol(d)))
    if (length(decoded)) cat("  [CODE vs LABEL] ", paste(decoded, collapse = "\n                   "), "\n")
    if (length(absent))  cat("  [DOC, NO DATA]  ", paste(absent, collapse = ", "), "\n")
    if (length(extra))   cat("  [DATA, NO DOC]  ", paste(extra,  collapse = ", "), "\n")
    cat("\n")
  }
}

if (length(missing_files))
  cat("Files not found or unreadable:\n  ", paste(missing_files, collapse = "\n  "), "\n")
if (issues == 0) cat("No mismatches.\n")
