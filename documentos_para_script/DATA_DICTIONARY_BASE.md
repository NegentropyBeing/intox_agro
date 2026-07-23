# Data Dictionary — Consolidated Analytical Base

**File:** `resultados/base_consolidada_sp_2014_2024.parquet`
**Script:** `Scripts/08_build_consolidated_base.R`
**Grain:** one row per municipality × year
**Rows:** 7,095 (645 municipalities × 11 years, 2014–2024)
**Columns:** 104

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
| 12 | `sih_n_hosp_t60` | integer | Hospital admissions specifically for pesticide poisoning (ICD T60, principal diagnosis) |
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

## Health outcomes — pesticide-specific (issue #7)

Pesticide-specific counterpart to the broad exogenous-intoxication counts above — kept
**alongside** them, not replacing them. Criteria confirmed by the study advisor
(2026-07-15). Municipalities with no recorded events are set to **0**, not NA.

> **Case definitions per system.**
> - **SIH** (`sih_n_hosp_pesticida`): principal diagnosis T60 (any subtype) **OR** a pesticide
>   external-cause code (X48/X68/X87/Y18) in the principal, secondary (`DIAG_SECUN`), or
>   associated (`CID_ASSO`) diagnosis field.
> - **SINAN** (`sinan_n_notif_pesticida`): primary toxic agent (`AGENTE_TOX`) in the pesticide
>   group (codes 02–06). **Strict primary-agent match** — free-text secondary-agent recovery
>   was considered but not implemented (see METHODS.md).
> - **SIM** (`sim_n_obitos_pesticida`): pesticide external-cause code (X48/X68/X87/Y18) as the
>   underlying cause (`CAUSABAS`). X87 (assault) falls outside the original IEXO extraction
>   range; the single 2014–2024 SP case was recovered via an accessory file
>   (`resultados/SIM/sim_x87_sp_2014_2024_probe.parquet`) and folded in — no full re-download.
>
> **Subtypes kept separate** (advisor request) so agents/intents can be analysed individually
> or regrouped downstream. Within each system the subtype columns sum to the system's
> pesticide total. Pesticide external-cause codes: X48 accidental, X68 intentional
> self-poisoning, X87 assault, Y18 undetermined intent.

| # | Variable | Type | Description |
|---|---|---|---|
| 22 | `sih_n_hosp_pesticida` | integer | Pesticide-specific hospital admissions (T60 principal **or** X48/X68/X87/Y18 in any kept diagnosis field) |
| 23 | `sinan_n_notif_pesticida` | integer | Pesticide-specific notifications (`AGENTE_TOX` ∈ 02–06) |
| 24 | `sim_n_obitos_pesticida` | integer | Pesticide-specific deaths (`CAUSABAS` ∈ X48/X68/X87/Y18) |

**Pediatric (ages 0–14) × pesticide.** Pesticide-specific counts restricted to ages 0–14, for the descriptive "who is most affected" report. Events are very sparse (pool years before interpreting). For SIH **time trends use the T60 column** (`sih_n_hosp_t60_0_14`): the full-flag column adds cases recoverable only via `DIAG_SECUN`/`CID_ASSO`, fields populated only in 2014 (see METHODS §3), so its series is inflated in 2014.

| # | Variable | Type | Description |
|---|---|---|---|
| 25 | `sih_n_hosp_t60_0_14` | integer | SIH hospitalisations, ages 0–14, pesticide (T60 principal only — temporally consistent) |
| 26 | `sih_n_hosp_pesticida_0_14` | integer | SIH hospitalisations, ages 0–14, full pesticide flag (T60 **or** X48/X68/X87/Y18 in any kept field; 2014-inflated — not for trends) |
| 27 | `sinan_n_notif_pesticida_0_14` | integer | SINAN notifications, ages 0–14, pesticide agents (`AGENTE_TOX` ∈ 02–06) |
| 28 | `sim_n_obitos_pesticida_0_14` | integer | SIM deaths, ages 0–14, pesticide external causes (`CAUSABAS` ∈ X48/X68/X87/Y18) |

**SIH — T60 subtype** (ICD-10 4th digit; DATASUS stores the code without the dot, e.g. `T600`):

| # | Variable | Type | Description |
|---|---|---|---|
| 29 | `sih_n_hosp_t60_0` | integer | Organophosphate & carbamate insecticides (T60.0) |
| 30 | `sih_n_hosp_t60_1` | integer | Halogenated insecticides (T60.1) |
| 31 | `sih_n_hosp_t60_2` | integer | Other insecticides (T60.2) |
| 32 | `sih_n_hosp_t60_3` | integer | Herbicides & fungicides (T60.3) |
| 33 | `sih_n_hosp_t60_4` | integer | Rodenticides (T60.4) |
| 34 | `sih_n_hosp_t60_8` | integer | Other pesticides (T60.8) |
| 35 | `sih_n_hosp_t60_9` | integer | Pesticide, unspecified (T60.9 or bare `T60`) |

**SINAN — pesticide agent type** (`AGENTE_TOX`):

| # | Variable | Type | Description |
|---|---|---|---|
| 36 | `sinan_n_notif_agrotox_agricola` | integer | Agricultural pesticide (02) |
| 37 | `sinan_n_notif_agrotox_domestico` | integer | Domestic/garden pesticide (03) |
| 38 | `sinan_n_notif_agrotox_saudepub` | integer | Public-health pesticide (04) |
| 39 | `sinan_n_notif_raticida` | integer | Rodenticide (05) |
| 40 | `sinan_n_notif_prod_veterinario` | integer | Veterinary product (06) |

**SIM — pesticide death by intent** (ICD-10 external cause):

| # | Variable | Type | Description |
|---|---|---|---|
| 41 | `sim_n_obitos_pest_acidental` | integer | Accidental (X48) |
| 42 | `sim_n_obitos_pest_autoprovocado` | integer | Intentional self-poisoning (X68) |
| 43 | `sim_n_obitos_pest_agressao` | integer | Assault (X87) |
| 44 | `sim_n_obitos_pest_indeterminado` | integer | Undetermined intent (Y18) |

---

## Health outcomes — rates

Crude incidence rates (41–46) are per 100,000 population: all-age counts over `pop_total`,
pediatric counts over `pop_0_14`. In-hospital case fatality (47–48) is the **percentage of
admissions that ended in death**, `NA` where there were no admissions.

| # | Variable | Type | Description |
|---|---|---|---|
| 45 | `taxa_hosp_100k` | double | SIH hospitalisations per 100,000 inhabitants (all ages) |
| 46 | `taxa_notif_100k` | double | SINAN notifications per 100,000 inhabitants (all ages) |
| 47 | `taxa_obitos_sim_100k` | double | SIM deaths per 100,000 inhabitants (all ages) |
| 48 | `taxa_hosp_0_14_100k` | double | SIH hospitalisations per 100,000 population aged 0–14 |
| 49 | `taxa_notif_0_14_100k` | double | SINAN notifications per 100,000 population aged 0–14 |
| 50 | `taxa_obitos_sim_0_14_100k` | double | SIM deaths per 100,000 population aged 0–14 |
| 51 | `taxa_letalidade_hosp` | double | In-hospital case fatality, all ages (%): `sih_n_obitos_hosp / sih_n_hosp × 100`; `NA` if no admissions |
| 52 | `taxa_letalidade_hosp_0_14` | double | In-hospital case fatality, ages 0–14 (%): `sih_n_obitos_hosp_0_14 / sih_n_hosp_0_14 × 100`; `NA` if no 0–14 admissions |

**Pesticide-specific rates** (per 100,000; all-age counts over `pop_total`, pediatric over `pop_0_14`). Pesticide events are sparse at the municipality × year grain — pool years (sum counts, then divide) rather than averaging municipal rates. For SIH time trends use the **T60** rate; the full-flag rate is inflated in 2014 (see counts 25–26 and METHODS §3).

| # | Variable | Type | Description |
|---|---|---|---|
| 53 | `taxa_hosp_t60_100k` | double | SIH pesticide (T60) hospitalisations per 100,000 (all ages) |
| 54 | `taxa_hosp_pesticida_100k` | double | SIH pesticide (full flag) hospitalisations per 100,000 (all ages; 2014-inflated) |
| 55 | `taxa_notif_pesticida_100k` | double | SINAN pesticide notifications per 100,000 (all ages) |
| 56 | `taxa_obitos_sim_pesticida_100k` | double | SIM pesticide deaths per 100,000 (all ages) |
| 57 | `taxa_hosp_t60_0_14_100k` | double | SIH pesticide (T60) hospitalisations per 100,000 population aged 0–14 |
| 58 | `taxa_hosp_pesticida_0_14_100k` | double | SIH pesticide (full flag) hospitalisations per 100,000 population aged 0–14 (2014-inflated) |
| 59 | `taxa_notif_pesticida_0_14_100k` | double | SINAN pesticide notifications per 100,000 population aged 0–14 |
| 60 | `taxa_obitos_sim_pesticida_0_14_100k` | double | SIM pesticide deaths per 100,000 population aged 0–14 |

---

## Pesticide exposure — drinking water (SISAGUA)

Source: `resultados/SISAGUA/sisagua_sp_2014_2024.parquet`

Municipalities with no sampling records have `NA` (not zero) in all SISAGUA variables —
absence of monitoring is distinct from absence of contamination.

| # | Variable | Type | Description |
|---|---|---|---|
| 61 | `sisagua_n_amostras` | integer | Total water samples tested for pesticides |
| 62 | `sisagua_n_amostras_detect` | integer | Samples with at least one quantifiable pesticide detection (`TIPO_RESULTADO == "NUMERICO"`) |
| 63 | `sisagua_n_pesticidas_detect` | integer | Number of distinct pesticide compounds detected in quantifiable amounts |
| 64 | `sisagua_pct_deteccao` | double | Percentage of samples with a quantifiable detection (0–100) |

---

## Pesticide exposure — agricultural production (PAM)

Source: `resultados/PROD_AGRO/pam_municipio_produto_ano.parquet` (rows where `produto == "Total"`)

| # | Variable | Type | Description |
|---|---|---|---|
| 65 | `pam_area_colhida_ha` | double | Total harvested area across all crops (hectares) |
| 66 | `pam_valor_prod_mil_reais` | double | Total agricultural production value, all crops (thousands BRL, current prices) |

---

## Pesticide exposure — formal agricultural employment (CAGED)

Source: `resultados/contextual/caged_agro_sp_municipio_ano.parquet`

Captures formal employment only (CLT contracts). Informal and seasonal workers are excluded.
**17 months in 2014–2019 are missing** due to corrupt files on the government FTP server —
annual totals for those years are underestimates. See `METHODS.md §11` for the full list.

| # | Variable | Type | Description |
|---|---|---|---|
| 67 | `caged_admissoes_agro` | integer | Formal agricultural admissions (CNAE division 01) |
| 68 | `caged_desligamentos_agro` | integer | Formal agricultural dismissals |
| 69 | `caged_saldo_liquido_agro` | integer | Net employment balance (admissions − dismissals) |
| 70 | `caged_movimentos_total_agro` | integer | Total movements (admissions + dismissals + transfers) |

---

## Fixed covariate — Agricultural Census 2017 (Censo Agropecuário)

Source: `resultados/PROD_AGRO/censo_agro_municipio_2017.parquet`

Single cross-section (2017). Treat as a **time-invariant municipal characteristic** —
the same value is repeated across all years in the base.

| # | Variable | Type | Description |
|---|---|---|---|
| 71 | `censo_uso_total_estab` | double | Total agricultural establishments in the municipality |
| 72 | `censo_pct_uso_agrotox` | double | % of establishments that used pesticides (0–100) |
| 73 | `censo_valor_agrotox_mil` | double | Municipal pesticide spending (thousands BRL, 2017 prices) |
| 74 | `censo_valor_total_mil` | double | Total agricultural spending (thousands BRL, 2017 prices) |

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
| 75 | `ivs` | double | Overall Social Vulnerability Index (0 = low vulnerability, 1 = high) |
| 76 | `ivs_infraestrutura_urbana` | double | Urban infrastructure sub-index |
| 77 | `ivs_capital_humano` | double | Human capital sub-index |
| 78 | `ivs_renda_e_trabalho` | double | Income and labour sub-index |
| 79 | `renda_per_capita` | double | Per-capita income (BRL, Census 2010) |
| 80 | `i_gini` | double | Gini coefficient |
| 81 | `t_analf_15m` | double | Adult illiteracy rate — population aged 15 and over (%) |
| 82 | `t_sem_agua_esgoto` | double | % households without piped water or sewage connection |
| 83 | `t_sem_lixo` | double | % households without garbage collection |
| 84 | `t_densidadem2` | double | % households with more than 2 persons per bedroom |
| 85 | `t_mort1` | double | Infant mortality rate (deaths per 1,000 live births) |
| 86 | `espvida` | double | Life expectancy at birth (years) |
| 87 | `t_razdep` | double | Age dependency ratio |


---

## Fixed covariate — Brazilian Deprivation Index / IBP (CIDACS/Fiocruz, Census 2010)

Source: `resultados/contextual/ibp_municipios_sp.parquet`

Single cross-section (Census 2010). Same value repeated across all years.
Scale is standardised (mean ≈ 0, negative = less deprived).

| # | Variable | Type | Description |
|---|---|---|---|
| 88 | `ibp_deprivation_mean` | double | Population-weighted mean deprivation score across census tracts |
| 89 | `ibp_deprivation_median` | double | Median deprivation score across census tracts |
| 90 | `ibp_pct_urban` | double | % of census tracts classified as urban |

---

## Fixed covariate — Paulista Social Vulnerability Index / IPVS (SEADE-SP, 2010)

Source: `resultados/contextual/ipvs_municipios_sp.parquet`

Single cross-section (2010). Same value repeated across all years.
The six groups are mutually exclusive and exhaustive — their percentages sum to 100 per municipality.

| # | Variable | Type | Description |
|---|---|---|---|
| 91 | `ipvs_pct_grupo1` | double | % households classified as **very low vulnerability** |
| 92 | `ipvs_pct_grupo2` | double | % households classified as **low vulnerability** |
| 93 | `ipvs_pct_grupo3` | double | % households classified as **medium-low vulnerability** |
| 94 | `ipvs_pct_grupo4` | double | % households classified as **medium vulnerability** |
| 95 | `ipvs_pct_grupo5` | double | % households classified as **high vulnerability** |
| 96 | `ipvs_pct_grupo6` | double | % households classified as **very high vulnerability** |

---

## Fixed covariate — Urban/Rural population split (IBGE Census 2022)

Source: `resultados/contextual/pop_rural_urb_sp_2022.parquet`

Single cross-section (Census 2022). Same value repeated across all years.
Municipalities that are 100% urban have `pop_rur_2022 == NA` and `pct_rural_2022 == 0`.

| # | Variable | Type | Description |
|---|---|---|---|
| 97 | `pop_urb_2022` | integer | Urban population (Census 2022) |
| 98 | `pop_rur_2022` | integer | Rural population (Census 2022); `NA` for fully urban municipalities |
| 99 | `pct_rural_2022` | double | % of population living in rural areas (0–100) |

---

## Fixed covariate — Racial composition (IBGE Census 2022, SIDRA T9606)

Source: `resultados/contextual/pop_raca_cor_sp_2022.parquet`

Single cross-section (Census 2022). Same value repeated across all years.
The five categories follow IBGE's self-declared colour/race classification and sum to ~100 per municipality.

| # | Variable | Type | Description |
|---|---|---|---|
| 100 | `pct_branca` | double | % population self-declared White |
| 101 | `pct_preta` | double | % population self-declared Black |
| 102 | `pct_amarela` | double | % population self-declared Yellow/Asian |
| 103 | `pct_parda` | double | % population self-declared Mixed-race (Parda) |
| 104 | `pct_indigena` | double | % population self-declared Indigenous |

---

## Notes for analysts

- **Join key:** `cod_ibge` (6-digit IBGE code) joins this base with all other project files.
- **Fixed covariates:** Censo Agro (2017), IVS, IBP, IPVS (all 2010), and the Urban/Rural and racial-composition splits (2022) are time-invariant — the same value repeats for every year in the base. Do not interpret year-to-year variation for these variables.
- **Broad vs. pesticide-specific outcomes:** columns 10–21 count *all* exogenous intoxication (medicines, chemicals, pesticides, etc.); columns 22–40 isolate pesticide poisoning. Both are provided; the pesticide-specific counts are a strict subset of the broad ones within each system. Use 22–24 (or the subtypes 25–40) when the analysis is about pesticides specifically.
- **Pesticide sparsity:** pesticide-specific events are few per municipality × year (statewide ≈ 1,127 hospitalisations, 24,463 notifications, and 698 deaths over the whole 2014–2024 period, concentrated in a handful of municipalities). Prefer **counts or pooled multi-year/region totals** over municipal `/100k` rates for pesticide-specific analysis. SINAN notifications are the least sparse of the three.
- **Pediatric (0–14) outcomes:** the `*_0_14` counts and their `taxa_*_0_14_100k` rates restrict to ages 0–14, using `pop_0_14` as the denominator. Use these — not the all-age `taxa_*_100k` — for any analysis limited to the 0–14 age group.
- **Case fatality (`taxa_letalidade_hosp*`):** these are computed **per municipality × year**, so at that grain they are noisy and often `NA` (small or zero pediatric admission counts). For a case-fatality rate over any aggregate (state, region, multi-year), **pool the counts** — `sum(sih_n_obitos_hosp_0_14) / sum(sih_n_hosp_0_14)` — rather than averaging the municipal rate.
- **SISAGUA NAs:** municipalities without water monitoring records have `NA` in all `sisagua_*` columns. Consider whether to impute, exclude, or model the missingness mechanism.
- **CAGED underestimation:** annual CAGED totals for 2014–2019 are underestimates due to missing months. Use with caution for trend analyses across the 2019→2020 format change.
- **Crude rates vs. adjusted rates:** `taxa_*` are crude rates. For age-standardised or sex-stratified rates, use the individual-level files in `resultados/SIH/`, `resultados/SINAN/`, `resultados/SIM/` combined with population disaggregated by age/sex from `resultados/contextual/populacao_sp_municipio_ano.parquet`.
