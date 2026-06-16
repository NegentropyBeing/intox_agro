# Data Processing Methods

This document describes the methodological decisions made during data collection, filtering,
and processing for the pesticide exposure and health outcomes dataset (São Paulo state, 2014–2024).
It is intended to support the *Data* and *Methods* sections of research publications arising
from this project.

**Working directory:** `Dados/` (R project root)
**Primary processing script:** `Scripts/07_build_outputs.R`
**Last updated:** 2026-05-28

---

## 1. Geographic scope

All health outcome datasets are restricted to **São Paulo state residents** (SP, IBGE state
code 35), using the patient's **municipality of residence** as the geographic key — not the
municipality where care was received. This distinction matters for the SIH (see Section 3).

The municipality identifier throughout all outputs is a **6-digit IBGE code** (`cod_ibge`),
consistent across all sources. Municipality names (`nome_municipio`) in the consolidated
base are sourced from the `geobr` R package (`read_municipality(code_muni = "SP", year = 2024)`),
which provides the complete list of 645 SP municipalities with canonical IBGE names. This
ensures all municipalities have a name regardless of whether they appear in agricultural
data sources such as PAM.

---

## 2. Time period

Health outcomes (SIH, SINAN) cover **2014–2024** (11 years). This range was determined by
the availability of pre-processed data provided by the collaborating team.

Contextual covariates (IVS, IPVS, IBP) are based on the **2010 Brazilian Census** and are
treated as fixed territorial characteristics, not time-varying exposures.

---

## 3. Hospital admissions — SIH-RD (DATASUS)

**Source file:** `Bancos/pre-consolidados/SIH/SIH_10_anos_IEXO_SP.parquet`
**Output:** `resultados/SIH/sih_iexo_sp_2014_2024.parquet`

### What the source file contains

The source file was assembled by the collaborating team and contains **all hospitalizations
recorded at SP-based hospitals** (filtered by `UF_ZI`, the hospital's municipality code,
starting with `35`). It covers all diagnoses and all patient origins — 27,830,311 records
in total.

### Inclusion criteria applied

Two filters were applied sequentially:

1. **Diagnosis (ICD-10):** principal diagnosis (`DIAG_PRINC`) matching exogenous intoxication
   codes: T36–T65 (poisoning by drugs and non-medicinal substances), X40–X49 (accidental
   poisoning), X60–X69 (intentional self-poisoning), Y10–Y19 (poisoning of undetermined
   intent). These are the same criteria used in the original SIH download scripts.

2. **Patient residence:** `MUNIC_RES` (6-digit municipality of residence) starting with `35`
   (São Paulo state). This ensures the unit of analysis is SP residents, not all patients
   treated in SP facilities.

| Step | Records |
|---|---|
| Raw (all admissions in SP hospitals, 2014–2024) | 27,830,311 |
| After ICD filter (exogenous intoxication only) | ~76,800 |
| After SP residence filter | **76,527** |

The ICD filter accounts for virtually all of the reduction (99.7%). The residence filter
removed only 273 records — patients from other states treated in SP for intoxication.

### Key variables and known limitations

- `MUNIC_RES`: 6-digit municipality of residence. Used as the geographic join key.
- `MORTE`: in-hospital death (values: "Sim"/"Não" in this dataset, not 0/1).
- `DIAG_PRINC`: 3-character ICD prefix used for filtering; full code retained in output.
- `CBOR` (occupation), `VINCPREV` (employment status), `INSTRU` (education): **present
  in the schema but almost entirely empty** in this pre-consolidated file (< 5 records
  with non-missing values). These fields are retained for structural compatibility but
  should not be used analytically without re-processing from raw DATASUS data.
- Financial columns (VAL_SH, VAL_SP, etc.) were dropped; only `VAL_TOT` (total
  reimbursement) was retained.
- `munRes*` geolocation fields (latitude, longitude, altitude, area) were dropped as
  municipality-level geographic joins use `MUNIC_RES` directly.

---

## 4. Notified intoxication cases — SINAN (DATASUS)

**Source file:** `Bancos/pre-consolidados/SINAN/SINAN_10_IEXO_SP.parquet`
**Output:** `resultados/SINAN/sinan_iexo_sp_2014_2024.parquet`

### What the source file contains

The source file contains **exogenous intoxication notifications (agravo IEXO) for SP
residents**, pre-filtered at source by `SG_UF = "35"` (SP state of residence). No
additional filtering was needed. The file covers 464,602 records from 2014–2024.

### Processing applied

Only administrative and system columns were dropped (batch transfer timestamps, system
routing codes, regional health codes redundant with municipality). All epidemiologically
relevant columns were retained, including:

- `ID_MN_RESI`: 6-digit municipality of residence (join key).
- `AGENTE_TOX`, `P_ATIVO_1/2/3`: toxic agent and active substances.
- `LAVOURA`: crop context (key proxy for agricultural pesticide exposure).
- `CIRCUNSTAN`: circumstances of exposure (occupational, accidental, etc.).
- `SIT_TRAB`, `MUN_EMP`: employment status and employer municipality.
- `EVOLUCAO`: outcome (recovery, death, etc.).
- `ano_origem`: integer year of origin file, used for temporal analysis.

### Note on municipality codes

`ID_MN_RESI` is the municipality of **residence**, not of exposure. For occupational
cases, `MUN_EMP` (employer's municipality) may be more appropriate as the exposure
geography.

---

## 5. Social Vulnerability Index — IVS (IPEA / Atlas do Desenvolvimento Humano)

**Source file:** `Bancos/pre-consolidados/IVS e IPVS/IVS/atlas-ivs_dadosbrutos_SP.xlsx`
**Output:** `resultados/contextual/ivs_municipios_sp_2010.parquet`

### What the source contains

The IVS (Índice de Vulnerabilidade Social) is published by IPEA as part of the Atlas do
Desenvolvimento Humano no Brasil. It provides social, demographic, and economic indicators
at the municipal level. The dataset includes multiple geographic levels (national, state,
metropolitan region, municipality) and two Census reference years: 2000 and 2010.

### Processing applied

Filtered to: `nivel == "regiao,uf,rm,municipio"` (municipal level), `uf == "35"` (SP),
`ano == "2010"` (most recent Census reference year). The variable selection follows the
list prepared by the research team (`variaveis_interesse_estudo_agrotoxicos.csv`), covering
five thematic domains:

- **Demographic profile:** age-group populations (children 0–14, elderly), dependency ratio,
  fertility rate.
- **Sanitation and environmental exposure:** % households without piped water/sewage, without
  garbage collection, with high density.
- **Socioeconomic conditions:** per-capita income, poverty rate, Gini index.
- **Education and child care:** adult illiteracy, % children in households with no literate
  adult, % single mothers without primary education.
- **Child health:** infant mortality, under-5 mortality, life expectancy at birth.
- **Child labor:** economic activity rate 10–14 years.
- **Urban/rural stratification:** `label_sit_dom` (urban vs. rural disaggregation).

### Row structure and municipal aggregation

After the `nivel`/`uf`/`ano` filters above, the output still contains **multiple rows per
municipality**. These are *demographic* breakdowns, not geographic ones: the source crosses
race (`label_cor`: Branco / Negro / Total Cor) by sex (`label_sexo`: Homem / Mulher / Total
Sexo) — a 3 × 3 grid — and each cell is additionally split by household situation
(`label_sit_dom`: Total / Urbano / Rural). Sub-municipal weighting areas (UDH) are **not**
included; they live under a different `nivel` value (`regiao,uf,rm,municipio,udh`) that is
excluded by the municipal-level filter.

The overall municipal value is the **Total Cor × Total Sexo × Total Situação de Domicílio**
cell. Because `label_cor` and `label_sexo` were not carried into the output parquet, that
cell is recovered indirectly in `08_build_consolidated_base.R`: filter
`label_sit_dom == "Total Situação de Domicílio"`, then take the **maximum-population** row per
municipality. The all-race/all-sex total has, by construction, a larger population than any
subgroup, so the maximum reliably lands on the totals cell. This was verified to select the
"Total Cor / Total Sexo" row for all 645 municipalities, with no exceptions.

> **Reproducibility note:** retaining `label_cor` and `label_sexo` in the output would let
> downstream code select the totals cell explicitly (`label_cor == "Total Cor" &
> label_sexo == "Total Sexo"`) rather than via the population heuristic. The two approaches
> give identical results today; the explicit filter is recommended if the pipeline is re-run.

### Known limitations

IVS is only available for Census years (2000 and 2010). For a study period of 2014–2024,
the 2010 values are used as a fixed contextual baseline. Municipalities are identified
by `municipio_6digt` (6-digit IBGE code), renamed to `cod_ibge` in the output.

---

## 6. Brazilian Deprivation Index — IBP (CIDACS / Fiocruz)

**Source file:** `Bancos/pre-consolidados/IBP/ibp_setor_censitario.csv`
**Output:** `resultados/contextual/ibp_municipios_sp.parquet`

### What the source contains

The IBP (Índice Brasileiro de Privação) is a small-area deprivation measure developed by
CIDACS/Fiocruz. The source file provides estimates at the **census-tract (setor censitário)
level** for the entire country, based on 2010 Census data. Full documentation:
`Bancos/pre-consolidados/IBP/Small-area Deprivation Measure for Brazil_ Data Documentation.pdf`.

Key variables: `BrazDep_measure` (continuous deprivation score), `Q_measure` (quintile),
`D_measure` (decile), `n_pop_hh` (population in private households, used as weight).

### Aggregation to municipality level

Census tracts already carry a `Cod_municipio` field (6-digit IBGE code), so no geographic
crosswalk was required. Aggregation to the municipal level was performed as:

- `ibp_deprivation_mean`: population-weighted mean of `BrazDep_measure` across tracts
  (`weight = n_pop_hh`).
- `ibp_deprivation_median`: unweighted median (alternative measure of central tendency).
- `ibp_pct_urban`: proportion of tracts classified as urban (`urban == 1`).
- `ibp_n_setores`: number of census tracts contributing to each municipality.

Only São Paulo state municipalities were retained (`Nome_da_UF == "São Paulo"`).

### Known limitations

Approximately 33% of census tracts in the SP sample have missing `BrazDep_measure` values
(suppressed in the original data, typically due to insufficient population in the tract).
These tracts were excluded from the weighted aggregation, which may introduce a small
upward bias in the municipal mean for municipalities with many suppressed tracts.

---

## 7. Paulista Index of Social Vulnerability — IPVS (SEADE-SP)

**Source file:** `Bancos/pre-consolidados/IVS e IPVS/IPVS/tratado/ipvs_tidy.csv`
**Output:** `resultados/contextual/ipvs_municipios_sp.parquet`

### What the source contains

The IPVS (Índice Paulista de Vulnerabilidade Social) is published by SEADE (Fundação
Sistema Estadual de Análise de Dados) for the state of São Paulo. It classifies census
tracts into six vulnerability groups based on 2010 Census indicators:

| Group | Label |
|---|---|
| 1 | Baixíssima Vulnerabilidade (very low vulnerability) |
| 2 | Muito Baixa Vulnerabilidade (low vulnerability) |
| 3 | Baixa Vulnerabilidade |
| 4 | Média Vulnerabilidade (medium) |
| 5 | Alta Vulnerabilidade (high) |
| 6 | Muito Alta Vulnerabilidade (very high) |

The source file covers all SP municipalities and is already in long format, but stored
as a single-column CSV with semicolon-separated fields (parsing required).

### Aggregation to municipality level

Rows with `setor == "Total"` represent municipality-level summaries (not individual census
tracts). The output provides, for each municipality:

- `ipvs_pct_grupo1` through `ipvs_pct_grupo6`: percentage of permanent private households
  in each vulnerability group.
- `municipio_codigo` (7 digits in source) truncated to 6-digit `cod_ibge`.

The distribution across groups is the primary analytical variable; higher proportions in
groups 5–6 indicate greater territorial vulnerability.

---

## 8. Pesticides in drinking water — SISAGUA (Ministry of Health)

**Source file:** `Bancos/pre-consolidados/SISAGUA/sisagua_agro_2014-2024.parquet`
**Output:** `resultados/SISAGUA/sisagua_sp_2014_2024.parquet`

### What the source contains

SISAGUA (Sistema de Informação de Vigilância da Qualidade da Água para Consumo Humano) is
the national drinking water surveillance system managed by the Brazilian Ministry of Health.
The source file covers the entire country (2014–2024) with 5,577,172 records — one row per
pesticide tested per water sample. São Paulo accounts for approximately 3.35 million records
(~60% of the national total).

### Processing applied

Filtered to `SG_UF == "SP"`. `CO_MUNICIPIO_IBGE` is already a 6-digit code in this
pre-consolidated file (no truncation required), renamed to `cod_ibge`. Administrative and
operational columns (institution identifiers, CNPJ numbers, regional office names, source
file metadata) were dropped. 18 of the original 40 columns were retained.

### Key variables

- `PARAMETRO_FINAL`: harmonized pesticide name (already cleaned in source).
- `TIPO_RESULTADO`: detection category —
  - `NUMERICO`: quantifiable detection; numeric value in `RESULTADO_NUM`.
  - `MENOR_LQ`: detected but below the quantification limit (LQ).
  - `MENOR_LD`: not detected (below detection limit, LD).
- `RESULTADO_NUM`: numeric concentration value (µg/L); only populated for `NUMERICO` records.
- `VMP`: maximum allowed concentration (Valor Máximo Permitido) under Brazilian regulation.
- `TP_ABASTECIMENTO`: water supply type (e.g., SAA — collective supply system).
- `CAT_CAPTACAO_FINAL`: water source category (surface vs. groundwater).

### Analytical note

For presence/absence analyses, `TIPO_RESULTADO == "NUMERICO"` identifies quantifiable
detections. Records with `MENOR_LQ` indicate presence below the quantification threshold —
whether to include them as detections depends on the analytical approach. Exceedances of
regulatory limits are identified by `RESULTADO_NUM > VMP`.

---

## 9. Agricultural production and pesticide use — PROD_AGRO (IBGE)

**Processing script:** `Scripts/06_process_prod_agro.R`
**Source files:** `Bancos/pre-consolidados/PROD_AGRO/` (PAM Excel files + Censo Agro 2017 Excel files)
**Outputs:** `resultados/PROD_AGRO/*.parquet`

### PAM — Permanent and Annual Agricultural Survey (2014–2024)

The PAM (Pesquisa Agrícola Municipal) is an annual IBGE survey covering temporary and
permanent crop production at the municipal level. Eight metrics are available per
municipality × crop × year:

| Variable | Description |
|---|---|
| `area_colhida_ha` | Harvested area (hectares) |
| `area_colhida_pct` | Harvested area as % of state total |
| `area_plant_ha` | Planted area (hectares) |
| `area_plant_pct` | Planted area as % of state total |
| `qtd_produzida` | Quantity produced (units vary by crop — see DATA_DICTIONARY.md) |
| `rend_medio` | Average yield (kg/ha) |
| `valor_prod_mil_reais` | Production value (thousands of BRL) |
| `valor_prod_pct` | Value as % of state total |

Output: `pam_municipio_produto_ano.parquet` — municipality × crop × year, 2014–2024.
Source codes in IBGE SIDRA: T5457.

### Censo Agropecuário 2017 — municipal-level outputs

Six tables from the 2017 Agricultural Census, all at the municipality level (SP state only):

**T6957** (`censo_agro_lavoura_2017.parquet`) — Crop-level production indicators for
temporary crops: number of establishments, quantity produced, quantity sold, production
value, sales value, harvested area.

**T6851 + T6899** (`censo_agro_municipio_2017.parquet`) — Municipality-level pesticide use
and expenditure: total establishments, number that used pesticides, breakdown by reason
for non-use, spending on pesticides and other inputs (thousands of BRL 2017).

**T6852** (`censo_agro_agrotox_orientacao_2017.parquet`) — Cross-tabulation of pesticide
use against source of technical guidance received. Columns cover five pesticide-use
categories (total, used, did not use, never uses, uses but did not need to) × eleven
guidance sources (government, own initiative, cooperatives, private companies, NGOs,
Sistema S, other, none). Key variable for understanding whether pesticide use is
technically supervised.

**T6855** (`censo_agro_manejo_solo_2017.parquet`) — Soil management practices by family
farming typology. Six management variables (no soil preparation, conventional tillage,
minimum tillage, no-till, etc.) with breakdown by family vs. non-family agriculture
(including Pronaf B, Pronaf V, and Pronamp categories).

**T6845** (`censo_agro_praticas_plantio_2017.parquet`) — Planting practices: number of
establishments using each of ten conservation practices (contour farming, crop rotation,
fallow, slope protection, riparian buffer restoration, reforestation, erosion control,
forest management, other, none).

### Known limitations

All Censo Agro data refer to 2017 and are used as fixed contextual covariates for the
2014–2024 study period. The PAM data are annual and match the study period, but crop-level
quantity units vary across crops (tonnes, thousand fruits, etc.) — aggregation across
crops using `produto == "Total"` avoids this issue at the municipal level.

---

## 10. Deaths from intoxication — SIM (DATASUS)

**Download script:** `Scripts/03_download_sim.R`
**Output:** `resultados/SIM/sim_iexo_sp_2014_2024.parquet`

### What the source contains

The SIM (Sistema de Informação sobre Mortalidade) is the national mortality registry
managed by DATASUS. Data are downloaded via the `microdatasus` R package, which fetches
raw DBC files and applies `process_sim()` to decode categorical fields into readable labels.

### Inclusion criteria

- **State:** São Paulo (SP) only — downloads one file per year, no all-Brazil iteration.
- **Cause of death (`CAUSABAS`):** same ICD-10 exogenous intoxication codes used for SIH
  and SINAN: T36–T65, X40–X49, X60–X69, Y10–Y19.
- **Period:** 2014–2024.

### Processing

Downloads are saved as individual year-chunks with automatic resume (existing chunks are
skipped on re-run). After all years are downloaded, chunks are assembled into a single
parquet. The following fields are retained where available:

| Field | Description |
|---|---|
| `DTOBITO` | Date of death |
| `CAUSABAS` | Underlying cause of death (ICD-10) |
| `CAUSABAS_O` | Original underlying cause (before processing) |
| `CODMUNRES` | Municipality of residence (6-digit IBGE code) |
| `CODMUNOCOR` | Municipality where death occurred |
| `SEXO_PADRONIZADO` | Sex (standardised labels from process_sim) |
| `IDADEanos` | Age in years (decoded by process_sim) |
| `RACACOR` | Race/color |
| `ESC2010` | Education level (2010 Census encoding) |
| `OCUP` | Occupation (CBO code) |
| `ACIDTRAB` | Work accident flag |
| `CIRCOBITO` | Death circumstances |

### Rate calculation

An optional commented section in the download script calculates age-sex specific and
standardised mortality rates for a selected year. This was the primary output in the
previous version (2022 only). For the 10-year individual-level base, rates are calculated
downstream from the parquet rather than pre-computed.

---

## 11. CAGED — Formal employment registry (MTE / PDET)

**Download script:** `Scripts/04_download_caged.R`
**Monthly outputs:** `resultados/CAGED/CAGED_YYYY_MM.parquet` (one file per month)
**Aggregate output:** `resultados/contextual/caged_agro_sp_municipio_ano.parquet`

### What CAGED records

CAGED (Cadastro Geral de Empregados e Desempregados) is Brazil's mandatory formal
employment registry. Employers must notify each admission and dismissal within 7 days.
It covers only **formal (CLT-registered) employment** — informal agricultural workers are
not captured.

### Download structure

The DATASUS FTP hosts two distinct CAGED series:

- **Old CAGED (2014–2019):** `ftp://ftp.mtps.gov.br/pdet/microdados/CAGED/YYYY/CAGEDEST_MMYYYY.7z`
  Column `Admitidos/Desligados` → harmonised to `saldomovimentação` (+1 = admission, −1 = dismissal)
- **New CAGED (≥2020):** `ftp://ftp.mtps.gov.br/pdet/microdados/NOVO%20CAGED/YYYY/YYYYMM/CAGEDMOV_YYYYMM.7z`
  Column `saldomovimentação` already in standardised format.

The download script harmonises both series into a common column schema. The
`saldomovimentação` column is standardised to integer {−1, 0, +1}: −1 = dismissal, +1 = admission,
0 = transfer (new CAGED only), NA = unexpected value.

### Occupation dictionary

Each record is joined to the official CBO 2002 occupation dictionary (`Bancos/cbo2002-ocupacao.csv`)
to decode the 6-digit `cbo2002ocupação` code to a human-readable label (`nome_ocupacao`).

### Agricultural filter and CNAE encoding

Each monthly parquet is filtered during download to **SP state only** (`uf == "35"`) and
**CNAE 2.0 division 01** (agriculture, livestock, and related services) before saving.
This reduces each file from ~2–3 million national records to ~20,000–90,000 SP agriculture
records, keeping total disk usage manageable.

**Important encoding difference between old and new CAGED:** in the old CAGED (≤2019),
the `subclasse` field stores CNAE codes as 7-character strings with the leading zero preserved
(e.g., `"0111300"` for crop farming). In the new CAGED (≥2020), the same field stores codes
as 6-character numeric strings without the leading zero (e.g., `"111300"`). The download
script normalises both to 7 digits using `formatC(..., width = 7, flag = "0")` before
applying the `substr(..., 1, 2) == "01"` filter.

The municipality code `município` uses 7 digits in the new CAGED (6-digit IBGE code + 1
check digit). The `cod_ibge` key is derived as `substr(município, 1, 6)`, which is correct
for both 6- and 7-digit inputs.

### Missing months — corrupt files on the MTE FTP

17 of 72 old CAGED months (2014–2019) failed to extract with both the `archive` R package
and the system `7za` (p7zip) tool, indicating the files are corrupt at the source on the
MTE FTP server. All new CAGED months (2020–2024, 60 files) downloaded and processed
successfully.

| Year | Missing months | Months available |
|---|---|---|
| 2014 | 03, 05, 09, 12 | 8/12 |
| 2015 | 01, 03, 07, 11 | 8/12 |
| 2016 | 03, 05 | 10/12 |
| 2017 | 04, 06, 12 | 9/12 |
| 2018 | — | **12/12** |
| 2019 | 01, 03, 08, 09 | 8/12 |
| 2020–2024 | — | **60/60** |

For annual analyses, counts from 2014–2019 (except 2018) will be underestimates
proportional to the fraction of missing months. Researchers should either exclude
2014–2019 from analyses relying on precise employment counts, restrict to 2018–2024
where coverage is complete, or apply a correction factor (divide by fraction of months
available) when using annual totals.

### Aggregate output variables

| Variable | Description |
|---|---|
| `cod_ibge` | 6-digit IBGE municipality code |
| `ano` | Reference year |
| `caged_admissoes_agro` | Formal agricultural admissions in the year |
| `caged_desligamentos_agro` | Formal agricultural dismissals in the year |
| `caged_saldo_liquido_agro` | Net balance (admissions minus dismissals) |
| `caged_movimentos_total_agro` | Total movements (admissions + dismissals + transfers) |

### Limitations

- CAGED captures only formal employment. São Paulo's agricultural sector includes a
  substantial share of informal (undeclared) workers, particularly for seasonal harvests.
  CAGED therefore represents a lower bound on total agricultural employment.
- Temporary/seasonal contracts may inflate monthly movement counts without reflecting
  stable headcount changes.
- 17 months in 2014–2019 are missing due to corrupt source files on the MTE FTP (see
  table above). All 2020–2024 months are complete.

---

## 12. Population estimates (IBGE / DATASUS POPSVS)

**Download script:** `Scripts/05_download_population_estimates.R`
**Source file:** `Bancos/populacao_estimativas_idade_simples_2001_2025.parquet`
**Output:** `resultados/contextual/populacao_sp_municipio_ano.parquet`

### Source

IBGE intercensal population estimates disseminated through DATASUS (POPSVS series).
Downloaded in DBF format from `ftp://ftp.datasus.gov.br/dissemin/publicos/IBGE/POPSVS/`.
The download script covers Brazil 2001–2025 with single-year age groups and sex disaggregation.

### Processing

Section 10 of `07_build_outputs.R` filters to São Paulo state and years 2014–2024,
yielding one row per municipality × year × sex × single-year age. This granularity
supports both crude and age/sex-standardised incidence and mortality rate calculation.

The CODMUN field from IBGE may be 6 or 7 digits depending on the release year; `cod_ibge`
is derived as `substr(CODMUN, 1, 6)` to standardise to 6 digits.

### Output variables

| Variable | Description |
|---|---|
| `cod_ibge` | 6-digit IBGE municipality code |
| `ano` | Calendar year |
| `sexo` | Sex ("Masculino" / "Feminino") |
| `idade` | Single-year age (0, 1, 2, … 80+) |
| `populacao` | IBGE estimated population |

---

## 13. Urban/Rural population split — IBGE Census 2022

**Source:** IBGE SIDRA table 9923 (`Bancos/pre-consolidados/T9923-pop_rural_urb.xlsx`)
**Script:** Section 11 of `Scripts/07_build_outputs.R`
**Output:** `resultados/contextual/pop_rural_urb_sp_2022.parquet`

### What it is

Table 9923 reports the resident population by urban/rural household situation for all
Brazilian municipalities, based on the 2022 Census. The SP extract used here contains
645 municipalities with absolute counts (urban/rural) and the derived % rural.

### Processing decisions

- **Source format:** the Excel has two sheets — absolute values and percentages. Both
  were available; absolute values were read and % rural derived from them to ensure
  consistency.
- **Municipality name join:** the source has no IBGE code. Municipality names
  (format `"Municipio (SP)"`) were joined with the PAM parquet to obtain `cod_ibge`.
- **Fully urban municipalities:** municipalities with zero rural population appear as
  `"-"` in the source. These are read as `NA` for `pop_rur_2022`; `pct_rural_2022`
  is set to `0`.
- **Cross-section use:** treat as a **fixed municipal covariate** — the same 2022 value
  applies to all years in the analytical base.

### Analytical relevance

The % rural population is an important structural covariate in pesticide exposure studies:
rural municipalities tend to have higher agricultural workforce concentration, lower
access to healthcare, and different CAGED coverage (informal rural workers are excluded
from CAGED). Including `pct_rural_2022` allows adjustment for this gradient.

---

## 14. Data completeness summary

All planned sources have been processed. The table below summarises the final status
of each output file.

### Health outcomes (individual-level)

| Source | Output | Records | Period | Status |
|---|---|---|---|---|
| SIH-RD | `resultados/SIH/sih_iexo_sp_2014_2024.parquet` | 76,527 | 2014–2024 | ✓ Complete |
| SINAN | `resultados/SINAN/sinan_iexo_sp_2014_2024.parquet` | 464,602 | 2014–2024 | ✓ Complete |
| SIM | `resultados/SIM/sim_iexo_sp_2014_2024.parquet` | 6,564 | 2014–2024 | ✓ Complete |

### Pesticide exposure

| Source | Output | Status | Notes |
|---|---|---|---|
| SISAGUA | `resultados/SISAGUA/sisagua_sp_2014_2024.parquet` | ✓ Complete | ~3.35M records (SP share of national data) |
| PAM | `resultados/PROD_AGRO/pam_municipio_produto_ano.parquet` | ✓ Complete | Municipality × crop × year, 2014–2024 |
| Censo Agro 2017 | `resultados/PROD_AGRO/censo_agro_*.parquet` (5 files) | ✓ Complete | Fixed 2017 snapshot; 6 tables |
| CAGED | `resultados/CAGED/CAGED_YYYY_MM.parquet` | ⚠ Partial | 115/132 months; 17 corrupt on source FTP (all in 2014–2019) |

### Contextual covariates (municipality-level)

| Source | Output | Status | Notes |
|---|---|---|---|
| IVS | `resultados/contextual/ivs_municipios_sp_2010.parquet` | ✓ Complete | Census 2010 baseline |
| IBP | `resultados/contextual/ibp_municipios_sp.parquet` | ✓ Complete | Census 2010 baseline |
| IPVS | `resultados/contextual/ipvs_municipios_sp.parquet` | ✓ Complete | Census 2010 baseline |
| CAGED aggregate | `resultados/contextual/caged_agro_sp_municipio_ano.parquet` | ⚠ Partial | Reflects the 115 available months |
| Population | `resultados/contextual/populacao_sp_municipio_ano.parquet` | ✓ Complete | SP, 2014–2024, single-year age × sex |
| Urban/Rural | `resultados/contextual/pop_rural_urb_sp_2022.parquet` | ✓ Complete | Census 2022 snapshot; 645 municipalities |
