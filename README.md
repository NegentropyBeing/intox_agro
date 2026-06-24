# Datalake — Pesticides and Health Outcomes (São Paulo, Brazil)

Data processing scripts and outputs for a study on the health effects of pesticide
exposure. All data cover **São Paulo state, 2014–2024** (or fixed census years where
noted). The project is a collaboration between the University of São Paulo (USP) and
the University of Michigan.

**Working directory:** open the project via `Agrotoxicos.Rproj` — all script paths are
relative to `Dados/`.

---

## Epidemiological Framework

The dataset is organised around three roles:

| Role | Sources | Rationale |
|---|---|---|
| **Health outcomes** | SIH-RD, SINAN, SIM | Hospitalizations, poisoning notifications, and deaths from exogenous intoxication (ICD-10 T36–T65, X40–X49, X60–X69, Y10–Y19) |
| **Pesticide exposure** | PAM, Censo Agro 2017, SISAGUA, CAGED | Agricultural production intensity, declared pesticide use and spending, pesticide residues in drinking water, and formal agricultural employment as an occupational exposure proxy |
| **Contextual covariates** | IVS, IBP, IPVS, Population estimates | Municipal-level socioeconomic vulnerability, deprivation, and population structure for rate calculation and covariate adjustment |

---

## Data Sources

| Source | Institution | Description | Epidemiological role | Coverage |
|---|---|---|---|---|
| **SIH-RD** | DATASUS/Ministry of Health | Inpatient admissions (public health system) filtered for intoxication ICD codes | Health outcome | SP, 2014–2024 |
| **SINAN** | DATASUS/Ministry of Health | Compulsory poisoning notifications (IEXO form) | Health outcome | SP, 2014–2024 |
| **SIM** | DATASUS/Ministry of Health | Death certificates filtered for intoxication ICD codes | Health outcome | SP, 2014–2024 |
| **CAGED** | Ministry of Labor (MTE) | Mandatory monthly registry of formal employment admissions and dismissals | Occupational exposure proxy | SP agriculture, 2014–2024 |
| **PAM** | IBGE | Municipal Agricultural Survey — harvested area, production, and value by crop | Agricultural intensity / exposure | SP, 2014–2024 |
| **Censo Agropecuário 2017** | IBGE | Agricultural Census — pesticide use, spending, soil management, planting practices | Fixed exposure covariate | SP, 2017 |
| **SISAGUA** | Ministry of Health | Drinking water surveillance — pesticide residue monitoring | Environmental exposure | SP, 2014–2024 |
| **IVS** | IPEA / Atlas do Desenvolvimento Humano | Social Vulnerability Index at municipality level | Contextual covariate | SP, Census 2010 |
| **IBP** | CIDACS / Fiocruz | Brazilian Index of Deprivation (census tract → municipality) | Contextual covariate | SP, Census 2010 |
| **IPVS** | SEADE-SP | Paulista Index of Social Vulnerability — share of domiciles per vulnerability group | Contextual covariate | SP, 2010 |
| **Population estimates** | IBGE / DATASUS | Intercensal population estimates by single-year age and sex | Denominator for rate calculation | SP, 2014–2024 |
| **Urban/Rural split** | IBGE | Census 2022 population by urban/rural situation per municipality | Contextual covariate | SP, Census 2022 |

### Why CAGED?

CAGED captures **formal agricultural employment** month by month and can be the most
structured longitudinal proxy for occupational pesticide exposure at the municipal
level. Its key limitation is that it excludes informal workers, who represent a
substantial share of seasonal agricultural labour in São Paulo. CAGED therefore
provides a lower bound on agricultural workforce size.

### Why the 2017 Agricultural Census as a fixed covariate?

The Censo Agropecuário is conducted every ~10 years and is the only source with
direct municipal-level data on pesticide use prevalence and spending. Despite being
a single point in time (2017), it reflects structural features of municipal agriculture
(crop mix, farm size, farming practices) that change slowly. It should be treated as a
**fixed municipal covariate**, not as a time-varying exposure.

---

## Folder Structure

```
Dados/
├── Agrotoxicos.Rproj           ← always open from here
├── README_EN.md
├── METHODS.md                  ← methodological decisions for each source
├── DATA_DICTIONARY.md          ← variable-level dictionary
│
├── Bancos/                     ← raw and auxiliary inputs
│   ├── cbo2002-ocupacao.csv    ← official CBO occupation dictionary
│   ├── Municipios.csv          ← municipality register with IBGE codes
│   ├── CNES/
│   └── pre-consolidados/       ← canonical pre-processed inputs 
│       ├── SIH/
│       ├── SINAN/
│       ├── SIM/                ← (if applicable)
│       ├── IVS e IPVS/
│       ├── IBP/
│       ├── SISAGUA/
│       └── PROD_AGRO/
│
├── Processados/                ← intermediate/temporary files
│   ├── chunks/                 ← SIM monthly chunks (auto-cleaned on re-run)
│   └── CAGED/                  ← CAGED .7z downloads and temp extractions
│
├── resultados/                 ← final outputs (parquet, zstd compressed)
│   ├── SIH/
│   ├── SINAN/
│   ├── SIM/
│   ├── SISAGUA/
│   ├── PROD_AGRO/
│   ├── CAGED/                  ← one parquet per month (individual-level)
│   └── contextual/             ← municipality-level contextual aggregates
│
└── Scripts/
    ├── 01_download_sih.R                    ← SIH-RD download and filter
    ├── 02_download_sinan.R                  ← SINAN/IEXO download and filter
    ├── 03_download_sim.R                    ← SIM download and filter
    ├── 04_download_caged.R                  ← CAGED automated download (2014–2024)
    ├── 05_download_population_estimates.R   ← IBGE intercensal estimates
    ├── 06_process_prod_agro.R               ← PAM + Censo Agropecuário processing
    ├── 07_build_outputs.R                   ← main consolidation (run after 01–06)
    └── 08_build_consolidated_base.R         ← final municipality × year base
```

---

## Prerequisites

**R (≥ 4.2)** and **RStudio**.

```r
install.packages(c(
  "arrow",        # read/write parquet
  "dplyr",
  "tidyr",
  "readxl",       # Excel files (PAM, Censo Agro)
  "readr",
  "stringr",
  "lubridate",
  "purrr",
  "foreign",      # .dbf files (population estimates)
  "archive",      # .7z extraction (CAGED)
  "data.table",   # fast CAGED reading
  "geobr"         # canonical municipality names (08_build_consolidated_base.R)
))

# microdatasus must be installed from GitHub:
# install.packages("remotes")
# remotes::install_github("rfsaldanha/microdatasus")
```

---

## How to Reproduce

Run scripts in this order. Steps 1–6 are independent (can run in any order among
themselves); steps 7 and 8 must run after all prior steps are complete.

### Steps 1–2 — `Scripts/01_download_sih.R` and `Scripts/02_download_sinan.R`
Download SIH-RD and SINAN/IEXO records from DATASUS, filter for SP and intoxication
ICD codes, and save pre-consolidated parquets in `Bancos/pre-consolidados/`.

### Step 3 — `Scripts/03_download_sim.R`
Downloads SIM death records from DATASUS (microdatasus), filters for SP and intoxication
ICD codes, and assembles `resultados/SIM/sim_iexo_sp_2014_2024.parquet`.
Automatic resume: existing monthly chunks are skipped on re-run.
**Estimated time:** 1–3 hours.

### Step 4 — `Scripts/04_download_caged.R`
Downloads all monthly CAGED files 2014–2024 from the MTE FTP, harmonises old/new
formats, joins the CBO occupation dictionary, and saves one parquet per month in
`resultados/CAGED/`. Automatic resume: existing months are skipped.
**Estimated time:** several hours (132 files).

### Step 5 — `Scripts/05_download_population_estimates.R`
Downloads IBGE intercensal population estimates 2001–2025 from DATASUS.
Output: `Bancos/populacao_estimativas_idade_simples_2001_2025.parquet`.
**Estimated time:** 10–30 min.

### Step 6 — `Scripts/06_process_prod_agro.R`
Processes PAM (2014–2024) and Censo Agropecuário 2017 spreadsheets from
`Bancos/pre-consolidados/PROD_AGRO/`. Produces 6 parquet files in `resultados/PROD_AGRO/`.
**Estimated time:** 5–15 min.

### Step 7 — `Scripts/07_build_outputs.R`
Consolidation script. Reads all pre-processed inputs and produces the final outputs.
Sections:

| Section | Source | Output |
|---|---|---|
| 1 — SIH | pre-consolidados/SIH | `resultados/SIH/sih_iexo_sp_2014_2024.parquet` |
| 2 — SINAN | pre-consolidados/SINAN | `resultados/SINAN/sinan_iexo_sp_2014_2024.parquet` |
| 3 — IVS | pre-consolidados/IVS | `resultados/contextual/ivs_municipios_sp_2010.parquet` |
| 4 — IBP | pre-consolidados/IBP | `resultados/contextual/ibp_municipios_sp.parquet` |
| 5 — IPVS | pre-consolidados/IPVS | `resultados/contextual/ipvs_municipios_sp.parquet` |
| 6 — SISAGUA | pre-consolidados/SISAGUA | `resultados/SISAGUA/sisagua_sp_2014_2024.parquet` |
| 7 — PROD_AGRO | resultados/PROD_AGRO | *(validates 6 files)* |
| 8 — SIM | resultados/SIM | *(validates sim parquet)* |
| 9 — CAGED | resultados/CAGED | `resultados/contextual/caged_agro_sp_municipio_ano.parquet` |
| 10 — Population | Bancos/populacao… | `resultados/contextual/populacao_sp_municipio_ano.parquet` |
| 11 — Urban/Rural | pre-consolidados/T9923 | `resultados/contextual/pop_rural_urb_sp_2022.parquet` |

Sections 7 and 8 validate that upstream outputs exist (run Steps 1–6 first).
Sections 9 and 10 require Steps 4 and 5, respectively.

---

## Output Files

### Health outcomes (individual-level)

| File | Grain | Period |
|---|---|---|
| `resultados/SIH/sih_iexo_sp_2014_2024.parquet` | hospital admission | 2014–2024 |
| `resultados/SINAN/sinan_iexo_sp_2014_2024.parquet` | poisoning notification | 2014–2024 |
| `resultados/SIM/sim_iexo_sp_2014_2024.parquet` | death | 2014–2024 |

### Pesticide exposure (individual/environmental)

| File | Grain | Period |
|---|---|---|
| `resultados/SISAGUA/sisagua_sp_2014_2024.parquet` | water sample × pesticide | 2014–2024 |
| `resultados/PROD_AGRO/pam_municipio_produto_ano.parquet` | municipality × crop × year | 2014–2024 |
| `resultados/PROD_AGRO/censo_agro_municipio_2017.parquet` | municipality | 2017 |
| `resultados/PROD_AGRO/censo_agro_lavoura_2017.parquet` | municipality × crop | 2017 |
| `resultados/PROD_AGRO/censo_agro_agrotox_orientacao_2017.parquet` | municipality × guidance type | 2017 |
| `resultados/PROD_AGRO/censo_agro_manejo_solo_2017.parquet` | municipality × farming typology | 2017 |
| `resultados/PROD_AGRO/censo_agro_praticas_plantio_2017.parquet` | municipality × planting practice | 2017 |
| `resultados/CAGED/CAGED_YYYY_MM.parquet` | employment record (monthly) | 2014–2024 |

### Contextual covariates (municipality-level)

| File | Grain | Period |
|---|---|---|
| `resultados/contextual/ivs_municipios_sp_2010.parquet` | municipality | Census 2010 |
| `resultados/contextual/ibp_municipios_sp.parquet` | municipality | Census 2010 |
| `resultados/contextual/ipvs_municipios_sp.parquet` | municipality | 2010 |
| `resultados/contextual/caged_agro_sp_municipio_ano.parquet` | municipality × year | 2014–2024 |
| `resultados/contextual/populacao_sp_municipio_ano.parquet` | municipality × year × sex × age | 2014–2024 |
| `resultados/contextual/pop_rural_urb_sp_2022.parquet` | municipality | Census 2022 |

All files use the **6-digit IBGE municipality code** (`cod_ibge`) as the primary join key,
except CAGED monthly parquets (use `município` → derive `cod_ibge` via `substr(município, 1, 6)`).

---

## Brazilian Health Data Infrastructure — Context for International Analysts

**DATASUS** is Brazil's national health informatics department. It maintains:

- **SIH-RD** *(Sistema de Informações Hospitalares)*: records all inpatient admissions
  reimbursed by the public health system (SUS). Each row is one admission. Primary
  diagnosis (`DIAG_PRINC`) uses ICD-10.

- **SIM** *(Sistema de Informações sobre Mortalidade)*: national death registry.
  Each row is one death certificate. Underlying cause (`CAUSABAS`) uses ICD-10.

- **SINAN** *(Sistema de Informação de Agravos de Notificação)*: compulsory notification
  system for reportable conditions. The IEXO form covers all exogenous poisoning cases.
  The `LAVOURA` (crop) field identifies the agricultural context when relevant — useful
  as a proxy for agricultural pesticide exposure.

- **SISAGUA**: drinking water quality surveillance. `TIPO_RESULTADO == "NUMERICO"` =
  quantifiable detection above the limit of quantification. `MENOR_LQ` = detected but
  below quantification limit. `MENOR_LD` = not detected.

**IBGE** is Brazil's national statistics institute, responsible for the census and PAM.

**CAGED** *(Cadastro Geral de Empregados e Desempregados)*: mandatory monthly registry
of all formal employment contracts. Format changed in January 2020 (column names and
coding differ); scripts handle harmonisation automatically.

**IVS / IBP / IPVS**: three independent municipal-level deprivation indices based on
the 2010 Brazilian Census. They measure different dimensions of vulnerability and can
be used individually or combined as adjustment covariates.

---

## ICD-10 Codes Used for Intoxication Filtering

Applied consistently across SIH, SINAN, and SIM:

| Range | Category |
|---|---|
| T36–T65 | Poisoning by drugs and non-medicinal substances |
| X40–X49 | Accidental poisoning |
| X60–X69 | Intentional self-poisoning |
| Y10–Y19 | Poisoning of undetermined intent |
| **T60** | **Toxic effects of pesticides** (subset of T36–T65; most specific for this study) |

---


## Data Availability Disclaimer

The repository automates processing wherever stable public interfaces were available. However, some historical data sources were not consistently accessible through automated download endpoints during the study period. 

SISAGUA is the main example: historical records were assembled from XML exports, treated and joined through a simple python script *(not in this repo)*. These constituted the only reliable source available for the period covered by the study. Consequently, full reproduction of the raw-data acquisition stage may require access to archival files that are not generated directly by the scripts in this repository.

---

## Notes for Analysts

- **Join key:** all contextual and outcome files use `cod_ibge` (6-digit IBGE code).
  CAGED monthly parquets use `município` (7-digit); strip the check digit with
  `substr(município, 1, 6)` before joining.

- **Census covariates as fixed:** IVS, IBP, IPVS, and Censo Agro 2017 data are from
  2010 or 2017. Treat them as **time-invariant municipal characteristics** when
  combining with annual outcome or employment data.

- **CAGED captures formal employment only:** informal agricultural workers (especially
  seasonal harvest labour) are not registered. CAGED counts are a lower bound on total
  agricultural workforce.

- **SIH records hospital of care, not residence:** the `MUNIC_MOV` field is the
  hospital's municipality. All SP filtering uses `MUNIC_RES` (patient's municipality
  of residence).

- **SINAN agricultural context proxy:** `LAVOURA` (crop field) is non-missing in cases
  where the poisoning was associated with agricultural activity. Use as a proxy for
  agricultural pesticide exposure context within poisoning notifications.

- **SISAGUA detection threshold:** for exposure analyses, consider restricting to
  `TIPO_RESULTADO == "NUMERICO"` (quantifiable detections) to avoid conflating
  true exposures with non-detections.

- **Methodological detail:** see `METHODS.md` for rationale and processing decisions
  for each source. See `DATA_DICTIONARY.md` for variable-level descriptions.
