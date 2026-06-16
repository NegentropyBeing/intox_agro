# Data Dictionary — Consolidated Analytical Base

**File:** `resultados/base_consolidada_sp_2014_2024.parquet`
**Script:** `Scripts/08_build_consolidated_base.R`
**Grain:** one row per municipality × year
**Rows:** 7,095 (645 municipalities × 11 years, 2014–2024)
**Columns:** 59

Variable groups can be included or excluded before saving by editing the `vars_*` vectors
in Part 7 of `08_build_consolidated_base.R`.

---

## Identifiers

| # | Variable | Type | Description |
|---|---|---|---|
| 1 | `cod_ibge` | character | 6-digit IBGE municipality code — primary join key across all project files |
| 2 | `nome_municipio` | character | Municipality name (IBGE canonical via geobr, e.g. `"Campinas"`) — present for all 645 municipalities |
| 3 | `ano` | integer | Calendar year (2014–2024) |

---

## Population (IBGE intercensal estimates)

Source: aggregated from `resultados/contextual/populacao_sp_municipio_ano.parquet`

> The source file is granular (one row per municipality × year × sex × single-year age,
> column `populacao`). The variables below are computed by `08_build_consolidated_base.R`
> and exist only in this consolidated base, not in the individual population file.

| # | Variable | Type | Description |
|---|---|---|---|
| 4 | `pop_total` | integer | Total estimated population |
| 5 | `pop_masculino` | integer | Male population |
| 6 | `pop_feminino` | integer | Female population |
| 7 | `pop_0_14` | integer | Population aged 0–14 |
| 8 | `pop_15_64` | integer | Population aged 15–64 |
| 9 | `pop_65plus` | integer | Population aged 65 and older |

---

## Health outcomes — counts (SIH, SINAN, SIM)

Municipalities with no recorded events are set to **0**, not NA.

Source: `resultados/SIH/`, `resultados/SINAN/`, `resultados/SIM/`

| # | Variable | Type | Description |
|---|---|---|---|
| 10 | `sih_n_hosp` | integer | Hospital admissions for exogenous intoxication (ICD T36–T65, X40–X49, X60–X69, Y10–Y19), by patient's municipality of residence |
| 11 | `sih_n_hosp_t60` | integer | Hospital admissions specifically for pesticide poisoning (ICD T60) |
| 12 | `sih_n_obitos_hosp` | integer | In-hospital deaths among intoxication admissions |
| 13 | `sih_dias_perm_media` | double | Mean length of hospital stay (days); `NA` if no admissions that year |
| 14 | `sinan_n_notif` | integer | Compulsory poisoning notifications (SINAN IEXO form) |
| 15 | `sinan_n_notif_agric` | integer | Notifications with agricultural context (`LAVOURA` field non-empty) — proxy for agricultural pesticide exposure |
| 16 | `sinan_n_obitos` | integer | Fatal notifications (EVOLUCAO == "2": death attributable to the notified intoxication) |
| 17 | `sim_n_obitos` | integer | Deaths from exogenous intoxication (death certificates, same ICD ranges as SIH) |

---

## Health outcomes — crude rates per 100,000 population

Derived from counts above divided by `pop_total`. `NA` if `pop_total` is missing.

| # | Variable | Type | Description |
|---|---|---|---|
| 18 | `taxa_hosp_100k` | double | SIH hospitalisations per 100,000 inhabitants |
| 19 | `taxa_notif_100k` | double | SINAN notifications per 100,000 inhabitants |
| 20 | `taxa_obitos_sim_100k` | double | SIM deaths per 100,000 inhabitants |

---

## Pesticide exposure — drinking water (SISAGUA)

Source: `resultados/SISAGUA/sisagua_sp_2014_2024.parquet`

Municipalities with no sampling records have `NA` (not zero) in all SISAGUA variables —
absence of monitoring is distinct from absence of contamination.

| # | Variable | Type | Description |
|---|---|---|---|
| 21 | `sisagua_n_amostras` | integer | Total water samples tested for pesticides |
| 22 | `sisagua_n_amostras_detect` | integer | Samples with at least one quantifiable pesticide detection (`TIPO_RESULTADO == "NUMERICO"`) |
| 23 | `sisagua_n_pesticidas_detect` | integer | Number of distinct pesticide compounds detected in quantifiable amounts |
| 24 | `sisagua_pct_deteccao` | double | Percentage of samples with a quantifiable detection (0–100) |

---

## Pesticide exposure — agricultural production (PAM)

Source: `resultados/PROD_AGRO/pam_municipio_produto_ano.parquet` (rows where `produto == "Total"`)

| # | Variable | Type | Description |
|---|---|---|---|
| 25 | `pam_area_colhida_ha` | double | Total harvested area across all crops (hectares) |
| 26 | `pam_valor_prod_mil_reais` | double | Total agricultural production value, all crops (thousands BRL, current prices) |

---

## Pesticide exposure — formal agricultural employment (CAGED)

Source: `resultados/contextual/caged_agro_sp_municipio_ano.parquet`

Captures formal employment only (CLT contracts). Informal and seasonal workers are excluded.
**17 months in 2014–2019 are missing** due to corrupt files on the government FTP server —
annual totals for those years are underestimates. See `METHODS.md §11` for the full list.

| # | Variable | Type | Description |
|---|---|---|---|
| 27 | `caged_admissoes_agro` | integer | Formal agricultural admissions (CNAE division 01) |
| 28 | `caged_desligamentos_agro` | integer | Formal agricultural dismissals |
| 29 | `caged_saldo_liquido_agro` | integer | Net employment balance (admissions − dismissals) |
| 30 | `caged_movimentos_total_agro` | integer | Total movements (admissions + dismissals + transfers) |

---

## Fixed covariate — Agricultural Census 2017 (Censo Agropecuário)

Source: `resultados/PROD_AGRO/censo_agro_municipio_2017.parquet`

Single cross-section (2017). Treat as a **time-invariant municipal characteristic** —
the same value is repeated across all years in the base.

| # | Variable | Type | Description |
|---|---|---|---|
| 31 | `censo_uso_total_estab` | double | Total agricultural establishments in the municipality |
| 32 | `censo_pct_uso_agrotox` | double | % of establishments that used pesticides (0–100) |
| 33 | `censo_valor_agrotox_mil` | double | Municipal pesticide spending (thousands BRL, 2017 prices) |
| 34 | `censo_valor_total_mil` | double | Total agricultural spending (thousands BRL, 2017 prices) |

---

## Fixed covariate — Social Vulnerability Index / IVS (IPEA, Census 2010)

Source: `resultados/contextual/ivs_municipios_sp_2010.parquet`

Single cross-section (Census 2010). Same value repeated across all years.

> All IVS variables are stored as numeric in the parquet. The source Excel uses a comma
> decimal separator, which is converted automatically during processing.
>
> Each value is the **overall municipal figure** — the "Total Cor × Total Sexo" cell of the
> source's race × sex grid (see METHODS.md §5 for how it is selected). It is not specific to
> any racial or sex subgroup.

| # | Variable | Type | Description |
|---|---|---|---|
| 35 | `ivs` | double | Overall Social Vulnerability Index (0 = low vulnerability, 1 = high) |
| 36 | `ivs_infraestrutura_urbana` | double | Urban infrastructure sub-index |
| 37 | `ivs_capital_humano` | double | Human capital sub-index |
| 38 | `ivs_renda_e_trabalho` | double | Income and labour sub-index |
| 39 | `renda_per_capita` | double | Per-capita income (BRL, Census 2010) |
| 40 | `i_gini` | double | Gini coefficient |
| 41 | `t_analf_15m` | double | Adult illiteracy rate — population aged 15 and over (%) |
| 42 | `t_sem_agua_esgoto` | double | % households without piped water or sewage connection |
| 43 | `t_sem_lixo` | double | % households without garbage collection |
| 44 | `t_densidadem2` | double | % households with more than 2 persons per bedroom |
| 45 | `t_mort1` | double | Infant mortality rate (deaths per 1,000 live births) |
| 46 | `espvida` | double | Life expectancy at birth (years) |
| 47 | `t_razdep` | double | Age dependency ratio |


---

## Fixed covariate — Brazilian Deprivation Index / IBP (CIDACS/Fiocruz, Census 2010)

Source: `resultados/contextual/ibp_municipios_sp.parquet`

Single cross-section (Census 2010). Same value repeated across all years.
Scale is standardised (mean ≈ 0, negative = less deprived).

| # | Variable | Type | Description |
|---|---|---|---|
| 48 | `ibp_deprivation_mean` | double | Population-weighted mean deprivation score across census tracts |
| 49 | `ibp_deprivation_median` | double | Median deprivation score across census tracts |
| 50 | `ibp_pct_urban` | double | % of census tracts classified as urban |

---

## Fixed covariate — Paulista Social Vulnerability Index / IPVS (SEADE-SP, 2010)

Source: `resultados/contextual/ipvs_municipios_sp.parquet`

Single cross-section (2010). Same value repeated across all years.
The six groups are mutually exclusive and exhaustive — their percentages sum to 100 per municipality.

| # | Variable | Type | Description |
|---|---|---|---|
| 51 | `ipvs_pct_grupo1` | double | % households classified as **very low vulnerability** |
| 52 | `ipvs_pct_grupo2` | double | % households classified as **low vulnerability** |
| 53 | `ipvs_pct_grupo3` | double | % households classified as **medium-low vulnerability** |
| 54 | `ipvs_pct_grupo4` | double | % households classified as **medium vulnerability** |
| 55 | `ipvs_pct_grupo5` | double | % households classified as **high vulnerability** |
| 56 | `ipvs_pct_grupo6` | double | % households classified as **very high vulnerability** |

---

## Fixed covariate — Urban/Rural population split (IBGE Census 2022)

Source: `resultados/contextual/pop_rural_urb_sp_2022.parquet`

Single cross-section (Census 2022). Same value repeated across all years.
Municipalities that are 100% urban have `pop_rur_2022 == NA` and `pct_rural_2022 == 0`.

| # | Variable | Type | Description |
|---|---|---|---|
| 57 | `pop_urb_2022` | integer | Urban population (Census 2022) |
| 58 | `pop_rur_2022` | integer | Rural population (Census 2022); `NA` for fully urban municipalities |
| 59 | `pct_rural_2022` | double | % of population living in rural areas (0–100) |

---

## Notes for analysts

- **Join key:** `cod_ibge` (6-digit IBGE code) joins this base with all other project files.
- **Fixed covariates:** Censo Agro (2017), IVS, IBP, and IPVS (all 2010) are time-invariant — the same value repeats for every year in the base. Do not interpret year-to-year variation for these variables.
- **SISAGUA NAs:** municipalities without water monitoring records have `NA` in all `sisagua_*` columns. Consider whether to impute, exclude, or model the missingness mechanism.
- **CAGED underestimation:** annual CAGED totals for 2014–2019 are underestimates due to missing months. Use with caution for trend analyses across the 2019→2020 format change.
- **Crude rates vs. adjusted rates:** `taxa_*` are crude rates. For age-standardised or sex-stratified rates, use the individual-level files in `resultados/SIH/`, `resultados/SINAN/`, `resultados/SIM/` combined with `pop_total` disaggregated by age/sex from `resultados/contextual/populacao_sp_municipio_ano.parquet`.
