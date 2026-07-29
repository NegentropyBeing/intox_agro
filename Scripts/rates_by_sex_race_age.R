# -----------------------------------------------------------------------------
# Hospitalization counts and rates by sex, race and age group (SIH, SP 2014-2024)
#
# Standalone helper. Not part of the numbered pipeline (01-08); run it whenever
# these breakdowns are needed. Reads only from resultados/, writes three CSVs.
#
#   Rscript Scripts/rates_by_sex_race_age.R
#
# Two case definitions are produced side by side in every table:
#   n_hosp_broad     - full exogenous intoxication filter (T36-T65, X40-49,
#                      X60-69, Y10-19)
#   n_hosp_pesticide - T60 or X48/X68/X87/Y18 in DIAG_PRINC
#
# READ BEFORE USING THE RACE TABLE
# Rates by race are approximate and their time trend is not interpretable:
#   (a) Brazil has no population by race and year between censuses, so the
#       denominator applies the 2022 census racial composition to every year;
#   (b) RACA_COR is missing in 23% of records in 2014 against 0% in 2024, so a
#       race-specific rate largely tracks the improvement in reporting.
# Sex and age group have neither problem: those denominators are the real IBGE
# population by municipality, year, sex and single year of age.
# -----------------------------------------------------------------------------

suppressMessages({
  library(arrow); library(dplyr); library(tidyr); library(readr)
})

outdir     <- "resultados"
PEST_CODES <- c("X48", "X68", "X87", "Y18")
# Childhood is split into 0-3, 4-7, 8-10 and 11-14; from 15 on the usual
# five-year bands are kept so the adult range stays comparable.
AGE_BREAKS <- c(0, 4, 8, 11, 15, seq(20, 80, 5), Inf)
AGE_LABELS <- c("0-3", "4-7", "8-10", "11-14", "15-19",
                paste0(seq(20, 75, 5), "-", seq(24, 79, 5)), "80+")
age_group  <- function(x) cut(x, AGE_BREAKS, AGE_LABELS, right = FALSE)

# --- Numerator: SIH records ---------------------------------------------------
# IDADE is stored as character and is not zero-padded, so as.integer() is
# mandatory: "5" <= "14" is FALSE and would silently drop ages 2-9.
sih <- read_parquet("resultados/SIH/sih_iexo_sp_2014_2024.parquet") %>%
  mutate(
    age_years = case_when(
      COD_IDADE %in% c("Dias", "Meses") ~ 0L,
      COD_IDADE == "Anos"               ~ as.integer(IDADE),
      TRUE                              ~ 100L + as.integer(IDADE)  # "Centena de anos"
    ),
    age_group = age_group(age_years),
    year      = as.integer(ANO_CMPT),
    sex       = recode(SEXO, Feminino = "Female", Masculino = "Male"),
    pesticide = substr(DIAG_PRINC, 1, 3) == "T60" |
                substr(DIAG_PRINC, 1, 3) %in% PEST_CODES,
    # SIH codes 03 = Parda and 04 = Amarela (Portaria SAS 719/2007). SINAN
    # inverts these two: do not reuse this mapping on CS_RACA.
    race      = recode(coalesce(RACA_COR, "99"),
                       "01" = "White", "02" = "Black", "03" = "Mixed (Parda)",
                       "04" = "Asian", "05" = "Indigenous",
                       .default = "Not reported")
  )

split_defs <- function(d, ...) {
  d %>%
    count(..., pesticide) %>%
    pivot_wider(names_from = pesticide, values_from = n, values_fill = 0L) %>%
    rename(n_hosp_pesticide = `TRUE`, n_hosp_other = `FALSE`) %>%
    mutate(n_hosp_broad = n_hosp_pesticide + n_hosp_other) %>%
    select(-n_hosp_other)
}

pop <- read_parquet("resultados/contextual/populacao_sp_municipio_ano.parquet") %>%
  mutate(year = as.integer(ano),
         sex  = recode(sexo, Feminino = "Female", Masculino = "Male"),
         age_group = age_group(idade))

# --- Table 1: sex x age group (true denominators) -----------------------------
den1 <- pop %>%
  group_by(year, sex, age_group) %>%
  summarise(population = sum(populacao), .groups = "drop")

t1 <- den1 %>%
  left_join(split_defs(sih, year, sex, age_group), c("year", "sex", "age_group")) %>%
  mutate(across(starts_with("n_hosp"), ~replace_na(.x, 0L)),
         rate_broad_per100k     = round(n_hosp_broad     / population * 1e5, 2),
         rate_pesticide_per100k = round(n_hosp_pesticide / population * 1e5, 3)) %>%
  arrange(year, sex, age_group)

# --- Table 2: race (approximate denominator - see header) ---------------------
# NA in the census percentages means the category was absent or suppressed in
# that municipality, so it is read as zero.
comp <- read_parquet("resultados/contextual/pop_raca_cor_sp_2022.parquet") %>%
  mutate(across(starts_with("pct_"), ~replace_na(.x, 0))) %>%
  pivot_longer(starts_with("pct_"), names_to = "race", values_to = "pct") %>%
  mutate(race = recode(sub("^pct_", "", race),
                       branca = "White", preta = "Black", parda = "Mixed (Parda)",
                       amarela = "Asian", indigena = "Indigenous"))

den2 <- pop %>%
  group_by(cod_ibge, year) %>%
  summarise(pm = sum(populacao), .groups = "drop") %>%
  inner_join(comp, "cod_ibge", relationship = "many-to-many") %>%
  group_by(year, race) %>%
  summarise(population_est = round(sum(pm * pct / 100)), .groups = "drop")

t2 <- split_defs(sih, year, race) %>%
  left_join(den2, c("year", "race")) %>%
  group_by(year) %>%
  mutate(pct_of_cases = round(100 * n_hosp_broad / sum(n_hosp_broad), 1)) %>%
  ungroup() %>%
  mutate(rate_broad_per100k     = round(n_hosp_broad     / population_est * 1e5, 2),
         rate_pesticide_per100k = round(n_hosp_pesticide / population_est * 1e5, 3)) %>%
  arrange(year, race)

# --- Table 3: pooled sex x race x age group (counts only, no denominator) -----
t3 <- split_defs(sih, sex, race, age_group) %>% arrange(sex, race, age_group)

write_csv(t1, file.path(outdir, "sih_hosp_rates_by_sex_agegroup_2014_2024.csv"))
write_csv(t2, file.path(outdir, "sih_hosp_rates_by_race_2014_2024.csv"))
write_csv(t3, file.path(outdir, "sih_hosp_counts_by_sex_race_agegroup_2014_2024.csv"))

stopifnot(sum(t1$n_hosp_broad) == nrow(sih))
cat("Wrote 3 files to", outdir, "-", nrow(sih), "hospitalizations,",
    sum(t1$n_hosp_pesticide), "pesticide-specific\n")
