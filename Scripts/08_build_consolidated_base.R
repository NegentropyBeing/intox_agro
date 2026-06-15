# ===================================================================
## 08_build_consolidated_base.R
##
## Assembles a municipality × year analytical base by joining all
## processed sources into a single flat parquet.
##
## Prerequisites: run scripts 01–07 first.
## Output: resultados/base_consolidada_sp_2014_2024.parquet
##
## FLEXIBLE VARIABLE SELECTION: scroll to Part 7 to choose which
## variable groups to include in the final output.
# ===================================================================
## Last updated: 2026-05-28
## Author: Isaac Schrarstzhaupt (github/isaacdata) - isaacns@usp.br
# ===================================================================

library(arrow)
library(dplyr)
library(tidyr)
library(geobr)

# ===========================================================================
# PART 1: SPINE — all SP municipalities × years 2014-2024
# ===========================================================================

cat("=== Building spine ===\n")

pop_raw <- read_parquet("resultados/contextual/populacao_sp_municipio_ano.parquet") |>
  mutate(ano = as.integer(ano))

# Municipality names from geobr (all SP municipalities, guaranteed complete)
mun_names <- geobr::read_municipality(code_muni = "SP", year = 2024,
                                      showProgress = FALSE) |>
  as_tibble() |>
  transmute(
    cod_ibge       = substr(as.character(code_muni), 1, 6),
    nome_municipio = name_muni
  )

spine <- pop_raw |>
  select(cod_ibge, ano) |>
  distinct() |>
  left_join(mun_names, by = "cod_ibge") |>
  arrange(cod_ibge, ano)

cat("Spine:", nrow(spine), "rows (", n_distinct(spine$cod_ibge),
    "municipalities ×", n_distinct(spine$ano), "years)\n\n")

# ===========================================================================
# PART 2: HEALTH OUTCOMES — aggregate to municipality × year
# ===========================================================================

cat("=== Aggregating health outcomes ===\n")

# --- 2a. SIH: hospital admissions ---
sih_agg <- read_parquet("resultados/SIH/sih_iexo_sp_2014_2024.parquet") |>
  mutate(
    cod_ibge = as.character(MUNIC_RES),
    ano      = as.integer(ANO_CMPT)
  ) |>
  group_by(cod_ibge, ano) |>
  summarise(
    sih_n_hosp          = n(),
    sih_n_hosp_t60      = sum(substr(DIAG_PRINC, 1, 3) == "T60", na.rm = TRUE),
    sih_n_obitos_hosp   = sum(MORTE == "Sim", na.rm = TRUE),
    sih_dias_perm_media = mean(suppressWarnings(as.numeric(DIAS_PERM)), na.rm = TRUE),
    .groups = "drop"
  )

cat("SIH:", nrow(sih_agg), "municipality-years\n")

# --- 2b. SINAN: poisoning notifications ---
sinan_agg <- read_parquet("resultados/SINAN/sinan_iexo_sp_2014_2024.parquet") |>
  mutate(
    cod_ibge = as.character(ID_MN_RESI),
    ano      = as.integer(ano_origem)
  ) |>
  group_by(cod_ibge, ano) |>
  summarise(
    sinan_n_notif       = n(),
    sinan_n_notif_agric = sum(!is.na(LAVOURA) & trimws(as.character(LAVOURA)) != "",
                              na.rm = TRUE),
    sinan_n_obitos      = sum(EVOLUCAO == "2", na.rm = TRUE),
    .groups = "drop"
  )

cat("SINAN:", nrow(sinan_agg), "municipality-years\n")

# --- 2c. SIM: deaths ---
sim_agg <- read_parquet("resultados/SIM/sim_iexo_sp_2014_2024.parquet") |>
  mutate(
    cod_ibge = as.character(CODMUNRES),
    ano      = as.integer(substr(as.character(DTOBITO), 1, 4))
  ) |>
  filter(!is.na(ano), ano %in% 2014:2024) |>
  group_by(cod_ibge, ano) |>
  summarise(sim_n_obitos = n(), .groups = "drop")

cat("SIM:", nrow(sim_agg), "municipality-years\n\n")

# ===========================================================================
# PART 3: EXPOSURE DATA — aggregate to municipality × year
# ===========================================================================

cat("=== Aggregating exposure data ===\n")

# --- 3a. SISAGUA: pesticides in drinking water ---
sisagua_agg <- read_parquet("resultados/SISAGUA/sisagua_sp_2014_2024.parquet") |>
  mutate(ano = as.integer(NU_ANO)) |>
  group_by(cod_ibge, ano) |>
  summarise(
    sisagua_n_amostras          = n(),
    sisagua_n_amostras_detect   = sum(TIPO_RESULTADO == "NUMERICO", na.rm = TRUE),
    sisagua_n_pesticidas_detect = n_distinct(
      PARAMETRO_FINAL[TIPO_RESULTADO == "NUMERICO"]
    ),
    .groups = "drop"
  ) |>
  mutate(
    sisagua_pct_deteccao = round(sisagua_n_amostras_detect / sisagua_n_amostras * 100, 2)
  )

cat("SISAGUA:", nrow(sisagua_agg), "municipality-years\n")

# --- 3b. PAM: agricultural production (municipal totals, produto == "Total") ---
pam_agg <- read_parquet("resultados/PROD_AGRO/pam_municipio_produto_ano.parquet") |>
  filter(produto == "Total") |>
  select(
    cod_ibge, ano,
    pam_area_colhida_ha      = area_colhida_ha,
    pam_valor_prod_mil_reais = valor_prod_mil_reais
  )

cat("PAM:", nrow(pam_agg), "municipality-years\n")

# --- 3c. CAGED: formal agricultural employment (already aggregated) ---
# Note: 17 months in 2014-2019 are missing due to corrupt source files;
# annual totals for those years are underestimates. See METHODS.md Section 11.
caged_agg <- read_parquet("resultados/contextual/caged_agro_sp_municipio_ano.parquet")

cat("CAGED:", nrow(caged_agg), "municipality-years\n\n")

# ===========================================================================
# PART 4: FIXED CONTEXTUAL COVARIATES (Census 2010 / Censo Agro 2017)
# ===========================================================================

cat("=== Loading contextual covariates ===\n")

# --- 4a. Censo Agropecuário 2017 ---
censo_agro <- read_parquet("resultados/PROD_AGRO/censo_agro_municipio_2017.parquet") |>
  transmute(
    cod_ibge,
    censo_uso_total_estab   = uso_total,
    censo_pct_uso_agrotox   = round(uso_utilizou / uso_total * 100, 2),
    censo_valor_agrotox_mil = valor_agrotoxicos,
    censo_valor_total_mil   = valor_total
  )

cat("Censo Agro:", nrow(censo_agro), "municipalities\n")

# --- 4b. IVS (IPEA / Atlas do Desenvolvimento Humano) ---
# The IVS contextual file has multiple rows per municipality (sub-municipal
# weighting areas and urban/rural breakdowns). Keep "Total Situação de Domicílio"
# and within that take the row with the largest population per municipality
# (the overall municipal aggregate).
ivs_raw <- read_parquet("resultados/contextual/ivs_municipios_sp_2010.parquet") |>
  filter(label_sit_dom == "Total Situação de Domicílio") |>
  mutate(populacao_num = suppressWarnings(as.numeric(gsub(",", ".", populacao)))) |>
  group_by(cod_ibge) |>
  slice_max(order_by = coalesce(populacao_num, 0L), n = 1, with_ties = FALSE) |>
  ungroup()

ivs_char_cols <- c(
  "ivs_infraestrutura_urbana", "ivs_capital_humano", "ivs_renda_e_trabalho",
  "renda_per_capita", "i_gini", "t_analf_15m",
  "t_sem_agua_esgoto", "t_sem_lixo", "t_densidadem2",
  "t_mort1", "espvida", "t_razdep"
)

ivs <- ivs_raw |>
  select(any_of(c("cod_ibge", "ivs", ivs_char_cols))) |>
  mutate(across(any_of(ivs_char_cols),
                ~ suppressWarnings(as.numeric(gsub(",", ".", .x)))))
rm(ivs_raw)

cat("IVS:", nrow(ivs), "municipalities\n")

# --- 4c. IBP (CIDACS / Fiocruz) ---
# IBP stores a 7-digit code (with check digit); strip to 6 digits to match spine
ibp <- read_parquet("resultados/contextual/ibp_municipios_sp.parquet") |>
  mutate(cod_ibge = substr(as.character(cod_ibge), 1, 6)) |>
  select(cod_ibge, ibp_deprivation_mean, ibp_deprivation_median, ibp_pct_urban)

cat("IBP:", nrow(ibp), "municipalities\n")

# --- 4d. IPVS (SEADE-SP) ---
ipvs <- read_parquet("resultados/contextual/ipvs_municipios_sp.parquet") |>
  select(cod_ibge, starts_with("ipvs_pct_grupo"))

cat("IPVS:", nrow(ipvs), "municipalities\n")

# --- 4e. Urban/Rural split (IBGE Census 2022) ---
pop_rural_urb <- read_parquet("resultados/contextual/pop_rural_urb_sp_2022.parquet")

cat("Urban/Rural:", nrow(pop_rural_urb), "municipalities\n\n")

# ===========================================================================
# PART 5: POPULATION STRUCTURE — aggregate to municipality × year
# ===========================================================================

cat("=== Aggregating population ===\n")

pop_agg <- pop_raw |>
  mutate(
    faixa = case_when(
      idade <= 14 ~ "0_14",
      idade <= 64 ~ "15_64",
      TRUE        ~ "65plus"
    )
  ) |>
  group_by(cod_ibge, ano) |>
  summarise(
    pop_total     = sum(populacao, na.rm = TRUE),
    pop_masculino = sum(populacao[sexo == "Masculino"], na.rm = TRUE),
    pop_feminino  = sum(populacao[sexo == "Feminino"],  na.rm = TRUE),
    pop_0_14      = sum(populacao[faixa == "0_14"],    na.rm = TRUE),
    pop_15_64     = sum(populacao[faixa == "15_64"],   na.rm = TRUE),
    pop_65plus    = sum(populacao[faixa == "65plus"],  na.rm = TRUE),
    .groups = "drop"
  )

cat("Population:", nrow(pop_agg), "municipality-years\n\n")

rm(pop_raw); gc()

# ===========================================================================
# PART 6: ASSEMBLE AND DERIVE RATES
# ===========================================================================

cat("=== Assembling consolidated base ===\n")

# Parquet sources may store cod_ibge as double — normalise to character before joining
coerce_cod <- function(df) mutate(df, cod_ibge = as.character(cod_ibge))
sisagua_agg   <- coerce_cod(sisagua_agg)
pam_agg       <- coerce_cod(pam_agg)
caged_agg     <- coerce_cod(caged_agg)
censo_agro    <- coerce_cod(censo_agro)
ivs           <- coerce_cod(ivs)
ibp           <- coerce_cod(ibp)
ipvs          <- coerce_cod(ipvs)
pop_rural_urb <- coerce_cod(pop_rural_urb)

base <- spine |>
  left_join(pop_agg,     by = c("cod_ibge", "ano")) |>
  left_join(sih_agg,     by = c("cod_ibge", "ano")) |>
  left_join(sinan_agg,   by = c("cod_ibge", "ano")) |>
  left_join(sim_agg,     by = c("cod_ibge", "ano")) |>
  left_join(sisagua_agg, by = c("cod_ibge", "ano")) |>
  left_join(pam_agg,     by = c("cod_ibge", "ano")) |>
  left_join(caged_agg,   by = c("cod_ibge", "ano")) |>
  left_join(censo_agro,    by = "cod_ibge") |>
  left_join(ivs,           by = "cod_ibge") |>
  left_join(ibp,           by = "cod_ibge") |>
  left_join(ipvs,          by = "cod_ibge") |>
  left_join(pop_rural_urb, by = "cod_ibge")

# Replace NA with 0 for count outcomes only
# (municipalities with no recorded events are truly zero, not missing)
count_vars <- c(
  "sih_n_hosp", "sih_n_hosp_t60", "sih_n_obitos_hosp",
  "sinan_n_notif", "sinan_n_notif_agric", "sinan_n_obitos",
  "sim_n_obitos",
  "sisagua_n_amostras", "sisagua_n_amostras_detect", "sisagua_n_pesticidas_detect"
)
base <- base |>
  mutate(across(all_of(intersect(count_vars, names(base))), ~ replace_na(.x, 0L)))

# Crude rates per 100,000 population
base <- base |>
  mutate(
    taxa_hosp_100k       = round(sih_n_hosp    / pop_total * 100000, 2),
    taxa_notif_100k      = round(sinan_n_notif  / pop_total * 100000, 2),
    taxa_obitos_sim_100k = round(sim_n_obitos   / pop_total * 100000, 2)
  )

cat("Full base assembled:", nrow(base), "rows ×", ncol(base), "columns\n\n")

# ===========================================================================
# PART 7: VARIABLE SELECTION
#
# Each group is a named vector of column names with inline comments.
# Comment out entire groups (or individual lines) to exclude from output.
# Identifiers are always required; do not remove them.
# ===========================================================================

vars_identifiers <- c(
  "cod_ibge",       # 6-digit IBGE municipality code (primary join key)
  "nome_municipio", # municipality name
  "ano"             # calendar year
)

vars_population <- c(
  "pop_total",     # total population (IBGE intercensal estimate)
  "pop_masculino", # male population
  "pop_feminino",  # female population
  "pop_0_14",      # population aged 0-14
  "pop_15_64",     # population aged 15-64
  "pop_65plus"     # population aged 65+
)

vars_outcomes_count <- c(
  "sih_n_hosp",          # hospitalisations, all intoxication ICD codes
  "sih_n_hosp_t60",      # hospitalisations, pesticide-specific (ICD T60)
  "sih_n_obitos_hosp",   # in-hospital deaths from intoxication
  "sih_dias_perm_media", # mean length of stay (days)
  "sinan_n_notif",       # poisoning notifications (SINAN IEXO)
  "sinan_n_notif_agric", # notifications with agricultural context (LAVOURA field non-empty)
  "sinan_n_obitos",      # fatal notifications (EVOLUCAO == 2)
  "sim_n_obitos"         # deaths from intoxication (death certificates)
)

vars_rates <- c(
  "taxa_hosp_100k",       # SIH hospitalisations per 100,000
  "taxa_notif_100k",      # SINAN notifications per 100,000
  "taxa_obitos_sim_100k"  # SIM deaths per 100,000
)

vars_sisagua <- c(
  "sisagua_n_amostras",          # water samples tested for pesticides
  "sisagua_n_amostras_detect",   # samples with at least one quantifiable detection
  "sisagua_n_pesticidas_detect", # distinct pesticides detected (TIPO_RESULTADO == NUMERICO)
  "sisagua_pct_deteccao"         # % samples with quantifiable detection
)

vars_pam <- c(
  "pam_area_colhida_ha",      # total harvested area, all crops (hectares)
  "pam_valor_prod_mil_reais"  # total agricultural production value (thousands BRL)
)

vars_caged <- c(
  "caged_admissoes_agro",       # formal agricultural admissions (CNAE 01)
  "caged_desligamentos_agro",   # formal agricultural dismissals
  "caged_saldo_liquido_agro",   # net employment balance
  "caged_movimentos_total_agro" # total movements (admissions + dismissals + transfers)
)

vars_censo_agro <- c(
  "censo_uso_total_estab",   # total agricultural establishments (Censo Agro 2017)
  "censo_pct_uso_agrotox",   # % establishments that used pesticides (2017)
  "censo_valor_agrotox_mil", # spending on pesticides, thousands BRL (2017)
  "censo_valor_total_mil"    # total agricultural spending, thousands BRL (2017)
)

vars_ivs <- c(
  "ivs",                       # overall Social Vulnerability Index (IPEA, 2010)
  "ivs_infraestrutura_urbana", # infrastructure sub-index
  "ivs_capital_humano",        # human capital sub-index
  "ivs_renda_e_trabalho",      # income and labour sub-index
  "renda_per_capita",          # per-capita income (BRL, 2010 Census)
  "i_gini",                    # Gini coefficient
  "t_analf_15m",               # adult illiteracy rate (population ≥15 years)
  "t_sem_agua_esgoto",         # % households without piped water or sewage
  "t_sem_lixo",                # % households without garbage collection
  "t_densidadem2",             # % households with > 2 persons per bedroom
  "t_mort1",                   # infant mortality rate (per 1,000 live births)
  "espvida",                   # life expectancy at birth (years)
  "t_razdep"                   # age dependency ratio
)

vars_ibp <- c(
  "ibp_deprivation_mean",   # population-weighted mean deprivation score (IBP, 2010)
  "ibp_deprivation_median", # median deprivation score across census tracts
  "ibp_pct_urban"           # % census tracts classified as urban
)

vars_ipvs <- c(
  "ipvs_pct_grupo1", # % households: very low vulnerability (IPVS, 2010)
  "ipvs_pct_grupo2", # % households: low vulnerability
  "ipvs_pct_grupo3", # % households: medium-low vulnerability
  "ipvs_pct_grupo4", # % households: medium vulnerability
  "ipvs_pct_grupo5", # % households: high vulnerability
  "ipvs_pct_grupo6"  # % households: very high vulnerability
)

vars_pop_rural <- c(
  "pop_urb_2022",   # urban population (IBGE Census 2022)
  "pop_rur_2022",   # rural population (IBGE Census 2022; NA = 100% urban municipality)
  "pct_rural_2022"  # % rural population (0–100; fixed 2022 covariate)
)

# ---------------------------------------------------------------------------
# Combine selected groups — comment out any line to exclude that group
# ---------------------------------------------------------------------------
vars_final <- c(
  vars_identifiers,     # always include
  vars_population,      # comment to exclude
  vars_outcomes_count,  # comment to exclude
  vars_rates,           # comment to exclude
  vars_sisagua,         # comment to exclude
  vars_pam,             # comment to exclude
  vars_caged,           # comment to exclude
  vars_censo_agro,      # comment to exclude
  vars_ivs,             # comment to exclude
  vars_ibp,             # comment to exclude
  vars_ipvs,            # comment to exclude
  vars_pop_rural        # comment to exclude
)

# ===========================================================================
# PART 8: SAVE OUTPUT
# ===========================================================================

base_final <- base |>
  select(any_of(vars_final))

cat("=== Final base ===\n")
cat("Rows:", nrow(base_final), "\n")
cat("Columns:", ncol(base_final), "\n")
cat("Municipalities:", n_distinct(base_final$cod_ibge), "\n")
cat("Period:", min(base_final$ano), "-", max(base_final$ano), "\n\n")

write_parquet(base_final, "resultados/base_consolidada_sp_2014_2024.parquet",
              compression = "zstd", compression_level = 10)

cat("Saved: resultados/base_consolidada_sp_2014_2024.parquet\n")

# Uncomment to also export as CSV (for Power BI, Stata, etc.)
# readr::write_csv2(base_final, "resultados/base_consolidada_sp_2014_2024.csv")
# cat("Saved: resultados/base_consolidada_sp_2014_2024.csv\n")
