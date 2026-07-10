# Data Dictionary — Consolidated Analytical Base

**File:** `resultados/base_consolidada_sp_2014_2024.parquet`
**Script:** `Scripts/08_build_consolidated_base.R`
**Grain:** one row per municipality × year
**Rows:** 7,095 (645 municipalities × 11 years, 2014–2024)
**Columns:** 73

Variable groups can be included or excluded before saving by editing the `vars_*` vectors
in Part 7 of `08_build_consolidated_base.R`.

---

## Identifiers

| # | Variable | Type | Description |
|---|---|---|---|
| 1 | `cod_ibge` | character | 6-digit IBGE municipality code — primary join key across all project files |
| 2 | `nome_municipio` | character | Municipality name (IBGE canonical via SIDRA T9606, e.g. `"Campinas"`) — present for all 645 municipalities |
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
| 7 | `pop_0_14` | integer | Population aged 0–14 (denominator for the pediatric rates below) |
| 8 | `pop_15_64` | integer | Population aged 15–64 |
| 9 | `pop_65plus` | integer | Population aged 65 and older |

---

## Health outcomes — counts (SIH, SINAN, SIM)

Municipalities with no recorded events are set to **0**, not NA.

Source: `resultados/SIH/`, `resultados/SINAN/`, `resultados/SIM/`

> **Pediatric (0–14) counts.** The `*_0_14` variables restrict each outcome to patients
> aged 0–14, using the age fields kept in the individual-level files. Age coding differs by
> system: SIH uses `COD_IDADE` ("Dias"/"Meses" = infants under 1 year, "Anos" = age in
> `IDADE`; "Centena de anos" = 100+, excluded); SINAN uses the DATASUS coded age
> `NU_IDADE_N` (values ≤ 4014 = ages 0–14); SIM uses the decoded `IDADEanos`. The all-ages
> columns are retained unchanged alongside them.

| # | Variable | Type | Description |
|---|---|---|---|
| 10 | `sih_n_hosp` | integer | Hospital admissions for exogenous intoxication (ICD T36–T65, X40–X49, X60–X69, Y10–Y19), by patient's municipality of residence |
| 11 | `sih_n_hosp_0_14` | integer | Hospital admissions among patients aged 0–14 |
| 12 | `sih_n_hosp_t60` | integer | Hospital admissions specifically for pesticide poisoning (ICD T60) |
| 13 | `sih_n_obitos_hosp` | integer | In-hospital deaths among intoxication admissions |
| 14 | `sih_n_obitos_hosp_0_14` | integer | In-hospital deaths among admissions aged 0–14 (numerator for pediatric case fatality) |
| 15 | `sih_dias_perm_media` | double | Mean length of hospital stay (days); `NA` if no admissions that year |
| 16 | `sinan_n_notif` | integer | Compulsory poisoning notifications (SINAN IEXO form) |
| 17 | `sinan_n_notif_0_14` | integer | Notifications among patients aged 0–14 |
| 18 | `sinan_n_notif_agric` | integer | Notifications with agricultural context (`LAVOURA` field non-empty) — proxy for agricultural pesticide exposure |
| 19 | `sinan_n_obitos` | integer | Fatal notifications (EVOLUCAO == "2": death attributable to the notified intoxication) |
| 20 | `sim_n_obitos` | integer | Deaths from exogenous intoxication (death certificates, same ICD ranges as SIH) |
| 21 | `sim_n_obitos_0_14` | integer | Deaths among individuals aged 0–14 |

---

## Health outcomes — rates

Crude incidence rates (22–27) are per 100,000 population: all-age counts over `pop_total`,
pediatric counts over `pop_0_14`. In-hospital case fatality (28–29) is the **percentage of
admissions that ended in death**, `NA` where there were no admissions.

| # | Variable | Type | Description |
|---|---|---|---|
| 22 | `taxa_hosp_100k` | double | SIH hospitalisations per 100,000 inhabitants (all ages) |
| 23 | `taxa_notif_100k` | double | SINAN notifications per 100,000 inhabitants (all ages) |
| 24 | `taxa_obitos_sim_100k` | double | SIM deaths per 100,000 inhabitants (all ages) |
| 25 | `taxa_hosp_0_14_100k` | double | SIH hospitalisations per 100,000 population aged 0–14 |
| 26 | `taxa_notif_0_14_100k` | double | SINAN notifications per 100,000 population aged 0–14 |
| 27 | `taxa_obitos_sim_0_14_100k` | double | SIM deaths per 100,000 population aged 0–14 |
| 28 | `taxa_letalidade_hosp` | double | In-hospital case fatality, all ages (%): `sih_n_obitos_hosp / sih_n_hosp × 100`; `NA` if no admissions |
| 29 | `taxa_letalidade_hosp_0_14` | double | In-hospital case fatality, ages 0–14 (%): `sih_n_obitos_hosp_0_14 / sih_n_hosp_0_14 × 100`; `NA` if no 0–14 admissions |

---

## Pesticide exposure — drinking water (SISAGUA)

Source: `resultados/SISAGUA/sisagua_sp_2014_2024.parquet`

Municipalities with no sampling records have `NA` (not zero) in all SISAGUA variables —
absence of monitoring is distinct from absence of contamination.

| # | Variable | Type | Description |
|---|---|---|---|
| 30 | `sisagua_n_amostras` | integer | Total water samples tested for pesticides |
| 31 | `sisagua_n_amostras_detect` | integer | Samples with at least one quantifiable pesticide detection (`TIPO_RESULTADO == "NUMERICO"`) |
| 32 | `sisagua_n_pesticidas_detect` | integer | Number of distinct pesticide compounds detected in quantifiable amounts |
| 33 | `sisagua_pct_deteccao` | double | Percentage of samples with a quantifiable detection (0–100) |

---

## Pesticide exposure — agricultural production (PAM)

Source: `resultados/PROD_AGRO/pam_municipio_produto_ano.parquet` (rows where `produto == "Total"`)

| # | Variable | Type | Description |
|---|---|---|---|
| 34 | `pam_area_colhida_ha` | double | Total harvested area across all crops (hectares) |
| 35 | `pam_valor_prod_mil_reais` | double | Total agricultural production value, all crops (thousands BRL, current prices) |

---

## Pesticide exposure — formal agricultural employment (CAGED)

Source: `resultados/contextual/caged_agro_sp_municipio_ano.parquet`

Captures formal employment only (CLT contracts). Informal and seasonal workers are excluded.
**17 months in 2014–2019 are missing** due to corrupt files on the government FTP server —
annual totals for those years are underestimates. See `METHODS.md §11` for the full list.

| # | Variable | Type | Description |
|---|---|---|---|
| 36 | `caged_admissoes_agro` | integer | Formal agricultural admissions (CNAE division 01) |
| 37 | `caged_desligamentos_agro` | integer | Formal agricultural dismissals |
| 38 | `caged_saldo_liquido_agro` | integer | Net employment balance (admissions − dismissals) |
| 39 | `caged_movimentos_total_agro` | integer | Total movements (admissions + dismissals + transfers) |

---

## Fixed covariate — Agricultural Census 2017 (Censo Agropecuário)

Source: `resultados/PROD_AGRO/censo_agro_municipio_2017.parquet`

Single cross-section (2017). Treat as a **time-invariant municipal characteristic** —
the same value is repeated across all years in the base.

| # | Variable | Type | Description |
|---|---|---|---|
| 40 | `censo_uso_total_estab` | double | Total agricultural establishments in the municipality |
| 41 | `censo_pct_uso_agrotox` | double | % of establishments that used pesticides (0–100) |
| 42 | `censo_valor_agrotox_mil` | double | Municipal pesticide spending (thousands BRL, 2017 prices) |
| 43 | `censo_valor_total_mil` | double | Total agricultural spending (thousands BRL, 2017 prices) |

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
| 44 | `ivs` | double | Overall Social Vulnerability Index (0 = low vulnerability, 1 = high) |
| 45 | `ivs_infraestrutura_urbana` | double | Urban infrastructure sub-index |
| 46 | `ivs_capital_humano` | double | Human capital sub-index |
| 47 | `ivs_renda_e_trabalho` | double | Income and labour sub-index |
| 48 | `renda_per_capita` | double | Per-capita income (BRL, Census 2010) |
| 49 | `i_gini` | double | Gini coefficient |
| 50 | `t_analf_15m` | double | Adult illiteracy rate — population aged 15 and over (%) |
| 51 | `t_sem_agua_esgoto` | double | % households without piped water or sewage connection |
| 52 | `t_sem_lixo` | double | % households without garbage collection |
| 53 | `t_densidadem2` | double | % households with more than 2 persons per bedroom |
| 54 | `t_mort1` | double | Infant mortality rate (deaths per 1,000 live births) |
| 55 | `espvida` | double | Life expectancy at birth (years) |
| 56 | `t_razdep` | double | Age dependency ratio |


---

## Fixed covariate — Brazilian Deprivation Index / IBP (CIDACS/Fiocruz, Census 2010)

Source: `resultados/contextual/ibp_municipios_sp.parquet`

Single cross-section (Census 2010). Same value repeated across all years.
Scale is standardised (mean ≈ 0, negative = less deprived).

| # | Variable | Type | Description |
|---|---|---|---|
| 57 | `ibp_deprivation_mean` | double | Population-weighted mean deprivation score across census tracts |
| 58 | `ibp_deprivation_median` | double | Median deprivation score across census tracts |
| 59 | `ibp_pct_urban` | double | % of census tracts classified as urban |

---

## Fixed covariate — Paulista Social Vulnerability Index / IPVS (SEADE-SP, 2010)

Source: `resultados/contextual/ipvs_municipios_sp.parquet`

Single cross-section (2010). Same value repeated across all years.
The six groups are mutually exclusive and exhaustive — their percentages sum to 100 per municipality.

| # | Variable | Type | Description |
|---|---|---|---|
| 60 | `ipvs_pct_grupo1` | double | % households classified as **very low vulnerability** |
| 61 | `ipvs_pct_grupo2` | double | % households classified as **low vulnerability** |
| 62 | `ipvs_pct_grupo3` | double | % households classified as **medium-low vulnerability** |
| 63 | `ipvs_pct_grupo4` | double | % households classified as **medium vulnerability** |
| 64 | `ipvs_pct_grupo5` | double | % households classified as **high vulnerability** |
| 65 | `ipvs_pct_grupo6` | double | % households classified as **very high vulnerability** |

---

## Fixed covariate — Urban/Rural population split (IBGE Census 2022)

Source: `resultados/contextual/pop_rural_urb_sp_2022.parquet`

Single cross-section (Census 2022). Same value repeated across all years.
Municipalities that are 100% urban have `pop_rur_2022 == NA` and `pct_rural_2022 == 0`.

| # | Variable | Type | Description |
|---|---|---|---|
| 66 | `pop_urb_2022` | integer | Urban population (Census 2022) |
| 67 | `pop_rur_2022` | integer | Rural population (Census 2022); `NA` for fully urban municipalities |
| 68 | `pct_rural_2022` | double | % of population living in rural areas (0–100) |

---

## Fixed covariate — Racial composition (IBGE Census 2022, SIDRA T9606)

Source: `resultados/contextual/pop_raca_cor_sp_2022.parquet`

Single cross-section (Census 2022). Same value repeated across all years.
The five categories follow IBGE's self-declared colour/race classification and sum to ~100 per municipality.

| # | Variable | Type | Description |
|---|---|---|---|
| 69 | `pct_branca` | double | % population self-declared White |
| 70 | `pct_preta` | double | % population self-declared Black |
| 71 | `pct_amarela` | double | % population self-declared Yellow/Asian |
| 72 | `pct_parda` | double | % population self-declared Mixed-race (Parda) |
| 73 | `pct_indigena` | double | % population self-declared Indigenous |

---

## Notes for analysts

- **Join key:** `cod_ibge` (6-digit IBGE code) joins this base with all other project files.
- **Fixed covariates:** Censo Agro (2017), IVS, IBP, IPVS (all 2010), and the Urban/Rural and racial-composition splits (2022) are time-invariant — the same value repeats for every year in the base. Do not interpret year-to-year variation for these variables.
- **Pediatric (0–14) outcomes:** the `*_0_14` counts and their `taxa_*_0_14_100k` rates restrict to ages 0–14, using `pop_0_14` as the denominator. Use these — not the all-age `taxa_*_100k` — for any analysis limited to the 0–14 age group.
- **Case fatality (`taxa_letalidade_hosp*`):** these are computed **per municipality × year**, so at that grain they are noisy and often `NA` (small or zero pediatric admission counts). For a case-fatality rate over any aggregate (state, region, multi-year), **pool the counts** — `sum(sih_n_obitos_hosp_0_14) / sum(sih_n_hosp_0_14)` — rather than averaging the municipal rate.
- **SISAGUA NAs:** municipalities without water monitoring records have `NA` in all `sisagua_*` columns. Consider whether to impute, exclude, or model the missingness mechanism.
- **CAGED underestimation:** annual CAGED totals for 2014–2019 are underestimates due to missing months. Use with caution for trend analyses across the 2019→2020 format change.
- **Crude rates vs. adjusted rates:** `taxa_*` are crude rates. For age-standardised or sex-stratified rates, use the individual-level files in `resultados/SIH/`, `resultados/SINAN/`, `resultados/SIM/` combined with population disaggregated by age/sex from `resultados/contextual/populacao_sp_municipio_ano.parquet`.
