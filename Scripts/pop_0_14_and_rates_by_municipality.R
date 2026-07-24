# -----------------------------------------------------------------------------
# Pediatric (0-14) population, intoxication counts and rates by municipality
# SIH and SINAN, Sao Paulo state, 2014-2024
#
# Standalone helper. Not part of the numbered pipeline (01-08); run it to
# regenerate resultados/pop_0_14_and_rates_by_municipality_2014_2024.csv.
#
#   Rscript Scripts/pop_0_14_and_rates_by_municipality.R
#
# Reads only from resultados/, so it runs on a clone of the repository without
# the raw Bancos/ folder.
#
# Two case definitions per system:
#   *_0_14_total      - full exogenous intoxication filter (T36-T65, X40-49,
#                       X60-69, Y10-19 for SIH; the IEXO notification form for
#                       SINAN)
#   *_pest_0_14_total - pesticide-specific. For SIH, T60 or X48/X68/X87/Y18 in
#                       DIAG_PRINC; for SINAN, AGENTE_TOX 02-06.
#
# The SIH pesticide definition deliberately keys on DIAG_PRINC alone. The wider
# pesticida flag also reads DIAG_SECUN and CID_ASSO, but those two fields are
# only populated in 2014, which makes the flag inconsistent over time. Keying on
# DIAG_PRINC gives 72 pediatric cases statewide and is comparable across the
# whole series.
#
# Rates are per 100,000 child-years: the denominator is the sum of the annual
# 0-14 population over the 11 years, so a rate is already an annual average and
# must not be divided by 11 again. Pesticide cases are very sparse at municipal
# level (40 of the 645 municipalities have any case at all), so prefer counts or
# pooled totals over municipal pesticide rates.
# -----------------------------------------------------------------------------

suppressMessages({
  library(arrow); library(dplyr); library(tidyr); library(readr)
})

outfile      <- "resultados/pop_0_14_and_rates_by_municipality_2014_2024.csv"
PEST_CODES   <- c("X48", "X68", "X87", "Y18")
SINAN_AGENTS <- c("02", "03", "04", "05", "06")

# --- Denominator: IBGE population, ages 0-14 ----------------------------------
pop <- read_parquet("resultados/contextual/populacao_sp_municipio_ano.parquet") %>%
  filter(idade <= 14) %>%
  mutate(year = as.integer(ano))

den <- pop %>%
  group_by(cod_ibge) %>%
  summarise(n_years               = n_distinct(year),
            pop_0_14_person_years = sum(populacao),
            pop_0_14_2024         = sum(populacao[year == 2024]),
            .groups = "drop") %>%
  mutate(pop_0_14_mean_annual = round(pop_0_14_person_years / n_years))

# --- Numerator: SIH -----------------------------------------------------------
# IDADE is character and not zero-padded, so as.integer() is mandatory:
# "5" <= "14" is FALSE and would silently drop ages 2-9.
sih <- read_parquet("resultados/SIH/sih_iexo_sp_2014_2024.parquet") %>%
  filter(COD_IDADE %in% c("Dias", "Meses") |
         (COD_IDADE == "Anos" & as.integer(IDADE) <= 14)) %>%
  mutate(pesticide = substr(DIAG_PRINC, 1, 3) == "T60" |
                     substr(DIAG_PRINC, 1, 3) %in% PEST_CODES) %>%
  group_by(cod_ibge = MUNIC_RES) %>%
  summarise(hosp_0_14_total      = n(),
            hosp_pest_0_14_total = sum(pesticide),
            .groups = "drop")

# --- Numerator: SINAN ---------------------------------------------------------
# NU_IDADE_N is the DATASUS coded age; the first digit is the unit, so values up
# to 4014 cover everyone under 15.
sinan <- read_parquet("resultados/SINAN/sinan_iexo_sp_2014_2024.parquet") %>%
  filter(NU_IDADE_N <= 4014) %>%
  mutate(pesticide = AGENTE_TOX %in% SINAN_AGENTS) %>%
  group_by(cod_ibge = ID_MN_RESI) %>%
  summarise(poison_0_14_total      = n(),
            poison_pest_0_14_total = sum(pesticide),
            .groups = "drop")

# --- Municipality names -------------------------------------------------------
names_mun <- read_parquet("resultados/base_consolidada_sp_2014_2024.parquet") %>%
  distinct(cod_ibge, nome_municipio)

# --- Assemble -----------------------------------------------------------------
# Municipalities with no case are absent from the numerators and become zero,
# not missing.
out <- den %>%
  left_join(names_mun, "cod_ibge") %>%
  left_join(sih,       "cod_ibge") %>%
  left_join(sinan,     "cod_ibge") %>%
  mutate(across(ends_with("_total"), ~replace_na(as.integer(.x), 0L)),
         hosp_rate_0_14_per100k_yr        = round(hosp_0_14_total        / pop_0_14_person_years * 1e5, 2),
         poison_rate_0_14_per100k_yr      = round(poison_0_14_total      / pop_0_14_person_years * 1e5, 2),
         hosp_pest_rate_0_14_per100k_yr   = round(hosp_pest_0_14_total   / pop_0_14_person_years * 1e5, 2),
         poison_pest_rate_0_14_per100k_yr = round(poison_pest_0_14_total / pop_0_14_person_years * 1e5, 2)) %>%
  select(cod_ibge, nome_municipio, n_years,
         hosp_0_14_total, poison_0_14_total,
         hosp_pest_0_14_total, poison_pest_0_14_total,
         pop_0_14_person_years, pop_0_14_mean_annual, pop_0_14_2024,
         hosp_rate_0_14_per100k_yr, poison_rate_0_14_per100k_yr,
         hosp_pest_rate_0_14_per100k_yr, poison_pest_rate_0_14_per100k_yr) %>%
  arrange(desc(pop_0_14_person_years))

# Records whose municipality of residence is 350000 ("Sao Paulo, municipality
# unknown") have no match in the population spine and are dropped here, as they
# are everywhere else in the pipeline.
stopifnot(nrow(out) == 645, !anyNA(out$nome_municipio))

write_csv(out, outfile)
cat("Wrote", outfile, "-", nrow(out), "municipalities\n")
cat("Statewide 0-14: hosp", sum(out$hosp_0_14_total),
    "| hosp pesticide", sum(out$hosp_pest_0_14_total),
    "| notifications", sum(out$poison_0_14_total),
    "| notifications pesticide", sum(out$poison_pest_0_14_total), "\n")
