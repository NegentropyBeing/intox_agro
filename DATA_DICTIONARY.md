# Data Dictionary
## Datalake — Pesticides and Health Outcomes (São Paulo state, 2014–2024)

All files use the **6-digit IBGE municipality code** (`cod_ibge`) as the primary join key,
except CAGED monthly parquets (use `município` → strip check digit with `substr(município, 1, 6)`).

Missing values in count outcomes represent municipalities with no recorded events (true zeros
are explicitly set to `0`). Missing values in exposure and covariate variables represent
municipalities absent from that source.

---

## 1. Consolidated Analytical Base — `base_consolidada_sp_2014_2024`

**File:** `resultados/base_consolidada_sp_2014_2024.parquet`
**Grain:** one row per municipality × year
**Period:** 2014–2024
**Municipalities:** 645 (all SP municipalities with population data)
**Script:** `Scripts/08_build_consolidated_base.R`

All sources below are joined here. Variable groups can be included or excluded via the
`vars_*` vectors in Part 7 of that script.

### Identifiers (always present)

| Variable | Type | Source | Description |
|---|---|---|---|
| `cod_ibge` | string | — | 6-digit IBGE municipality code |
| `nome_municipio` | string | geobr | Municipality name (IBGE canonical, e.g. `"Campinas"`) |
| `ano` | integer | — | Calendar year (2014–2024) |

### Population (from `populacao_sp_municipio_ano.parquet`)

| Variable | Type | Description |
|---|---|---|
| `pop_total` | integer | Total estimated population |
| `pop_masculino` | integer | Male population |
| `pop_feminino` | integer | Female population |
| `pop_0_14` | integer | Population aged 0–14 |
| `pop_15_64` | integer | Population aged 15–64 |
| `pop_65plus` | integer | Population aged 65 and older |

### Health outcomes — counts (NA → 0 for municipalities with no events)

| Variable | Type | Source | Description |
|---|---|---|---|
| `sih_n_hosp` | integer | SIH-RD | Hospitalisations for exogenous intoxication (ICD T36–T65, X40–X49, X60–X69, Y10–Y19) |
| `sih_n_hosp_t60` | integer | SIH-RD | Hospitalisations specifically for pesticide poisoning (ICD T60) |
| `sih_n_obitos_hosp` | integer | SIH-RD | In-hospital deaths among intoxication admissions |
| `sih_dias_perm_media` | double | SIH-RD | Mean length of stay (days) — `NA` if no admissions |
| `sinan_n_notif` | integer | SINAN | Compulsory poisoning notifications (IEXO form) |
| `sinan_n_notif_agric` | integer | SINAN | Notifications with agricultural context (`LAVOURA` field non-empty) |
| `sinan_n_obitos` | integer | SINAN | Fatal notifications (EVOLUCAO == "2": death from the notified condition) |
| `sim_n_obitos` | integer | SIM | Deaths from exogenous intoxication (death certificates, ICD T36–T65, X40–X49, X60–X69, Y10–Y19) |

### Health outcomes — crude rates per 100,000 population

| Variable | Type | Description |
|---|---|---|
| `taxa_hosp_100k` | double | SIH hospitalisations per 100,000 |
| `taxa_notif_100k` | double | SINAN notifications per 100,000 |
| `taxa_obitos_sim_100k` | double | SIM deaths per 100,000 |

### SISAGUA — drinking water pesticide monitoring

| Variable | Type | Description |
|---|---|---|
| `sisagua_n_amostras` | integer | Total water samples tested for pesticides |
| `sisagua_n_amostras_detect` | integer | Samples with at least one quantifiable detection (`TIPO_RESULTADO == "NUMERICO"`) |
| `sisagua_n_pesticidas_detect` | integer | Distinct pesticides detected in quantifiable amounts |
| `sisagua_pct_deteccao` | double | Percentage of samples with quantifiable detection |

### PAM — agricultural production (municipal totals, 2014–2024)

| Variable | Type | Description |
|---|---|---|
| `pam_area_colhida_ha` | double | Total harvested area, all crops (hectares) |
| `pam_valor_prod_mil_reais` | double | Total agricultural production value (thousands BRL) |

### CAGED — formal agricultural employment (2014–2024)

| Variable | Type | Description |
|---|---|---|
| `caged_admissoes_agro` | integer | Formal agricultural admissions (CNAE 01) |
| `caged_desligamentos_agro` | integer | Formal agricultural dismissals |
| `caged_saldo_liquido_agro` | integer | Net employment balance (admissions − dismissals) |
| `caged_movimentos_total_agro` | integer | Total employment movements (admissions + dismissals + transfers) |

> **Note:** 17 months in 2014–2019 are missing from CAGED due to corrupt source files on
> the government FTP server. Annual totals for those years are underestimates. See METHODS.md §11.

### Censo Agropecuário 2017 — fixed municipal covariate

| Variable | Type | Description |
|---|---|---|
| `censo_uso_total_estab` | double | Total agricultural establishments (Censo Agro 2017) |
| `censo_pct_uso_agrotox` | double | % of establishments that used pesticides (0–100) |
| `censo_valor_agrotox_mil` | double | Municipal spending on pesticides (thousands BRL, 2017) |
| `censo_valor_total_mil` | double | Total agricultural spending (thousands BRL, 2017) |

### IVS — Social Vulnerability Index (IPEA / Atlas do Des. Humano, Census 2010)

| Variable | Type | Description |
|---|---|---|
| `ivs` | double | Overall Social Vulnerability Index (0 = low, 1 = high) |
| `ivs_infraestrutura_urbana` | double | Infrastructure sub-index |
| `ivs_capital_humano` | double | Human capital sub-index |
| `ivs_renda_e_trabalho` | double | Income and labour sub-index |
| `renda_per_capita` | double | Per-capita income (BRL, 2010 Census) |
| `i_gini` | double | Gini coefficient |
| `t_analf_15m` | double | Adult illiteracy rate (population ≥ 15 years, %) |
| `t_sem_agua_esgoto` | double | % households without piped water or sewage |
| `t_sem_lixo` | double | % households without garbage collection |
| `t_densidadem2` | double | % households with > 2 persons per bedroom |
| `t_mort1` | double | Infant mortality rate (per 1,000 live births) |
| `espvida` | double | Life expectancy at birth (years) |
| `t_razdep` | double | Age dependency ratio |

### IBP — Brazilian Deprivation Index (CIDACS / Fiocruz, Census 2010)

| Variable | Type | Description |
|---|---|---|
| `ibp_deprivation_mean` | double | Population-weighted mean deprivation score across census tracts |
| `ibp_deprivation_median` | double | Median deprivation score across census tracts |
| `ibp_pct_urban` | double | % census tracts classified as urban |

### IPVS — Paulista Social Vulnerability Index (SEADE-SP, 2010)

| Variable | Type | Description |
|---|---|---|
| `ipvs_pct_grupo1` | double | % households: very low vulnerability |
| `ipvs_pct_grupo2` | double | % households: low vulnerability |
| `ipvs_pct_grupo3` | double | % households: medium-low vulnerability |
| `ipvs_pct_grupo4` | double | % households: medium vulnerability |
| `ipvs_pct_grupo5` | double | % households: high vulnerability |
| `ipvs_pct_grupo6` | double | % households: very high vulnerability |

---

## 2. SIH — Hospital Admissions (individual-level)

**File:** `resultados/SIH/sih_iexo_sp_2014_2024.parquet`
**Grain:** one row per hospital admission
**Period:** 2014–2024
**Records:** ~77,000
**Source:** DATASUS — SIH-RD (Sistema de Informações Hospitalares)
**Pre-filter:** primary diagnosis (`DIAG_PRINC`) in ICD-10 ranges T36–T65, X40–X49, X60–X69, Y10–Y19; SP patient residence (`MUNIC_RES` starts with "35")

| Variable | Type | Description |
|---|---|---|
| `N_AIH` | string | Authorization number (unique admission ID) |
| `ANO_CMPT` | integer | Year of hospitalisation |
| `MES_CMPT` | integer | Month of hospitalisation (1–12) |
| `DT_INTER` | string | Admission date |
| `DT_SAIDA` | string | Discharge date |
| `MUNIC_RES` | string | **Municipality of patient's residence** (6-digit IBGE code). Use for municipality-level analysis |
| `MUNIC_MOV` | string | Municipality of the hospital |
| `CNES` | string | Healthcare facility code (7 digits) |
| `NASC` | string | Patient date of birth |
| `COD_IDADE` | string | Age unit: `1`=hours, `2`=days, `3`=months, `4`=years |
| `IDADE` | string | Patient age (in units given by `COD_IDADE`) |
| `SEXO` | string | Sex: `1`=male, `3`=female, `0`=NA |
| `RACA_COR` | string | Race/ethnicity (coded) |
| `DIAG_PRINC` | string | Primary diagnosis (ICD-10) |
| `DIAG_SECUN` | string | Secondary diagnosis (ICD-10) |
| `CID_MORTE` | string | ICD-10 code of death cause (when applicable) |
| `MORTE` | string | In-hospital death: `"Sim"` = yes, `"Não"` = no |
| `DIAS_PERM` | string | Length of stay (days) |
| `QT_DIARIAS` | string | Number of daily AIH fees charged |
| `MARCA_UTI` | string | ICU marker |
| `VAL_TOT` | string | Total reimbursement value (BRL) |

> For **pesticide-specific** cases, filter `substr(DIAG_PRINC, 1, 3) == "T60"`.
> Use `MUNIC_RES`, not `MUNIC_MOV`, for patient's municipality of residence.

---

## 3. SINAN — Poisoning Notifications (individual-level)

**File:** `resultados/SINAN/sinan_iexo_sp_2014_2024.parquet`
**Grain:** one row per compulsory notification
**Period:** 2014–2024
**Records:** ~465,000
**Source:** DATASUS — SINAN, IEXO form (Intoxicações Exógenas)
**Pre-filter:** SP patient residence (`SG_UF == "35"`); all exogenous intoxication notifications

Key analytical variables:

| Variable | Type | Description |
|---|---|---|
| `ID_MN_RESI` | string | **Municipality of patient's residence** (6-digit IBGE code). Use for municipality-level analysis |
| `SG_UF` | string | State code of residence — stored as numeric string (`"35"` for SP) |
| `ano_origem` | integer | Reference year (use for temporal analysis) |
| `NU_ANO` | string | Year of notification |
| `DT_NOTIFIC` | date | Notification date |
| `DT_SIN_PRI` | date | Date of first symptoms |
| `ANO_NASC` | string | Patient birth year |
| `CS_SEXO` | string | Sex: `"M"` = male, `"F"` = female |
| `CS_RACA` | string | Race/ethnicity (coded 1–5) |
| `AGENTE_TOX` | string | Toxic agent category code |
| `LAVOURA` | string | **Crop associated with exposure** (e.g. `"112.SOJA"`, `"088.MILHO"`). Non-empty values indicate agricultural context |
| `CIRCUNSTAN` | string | Circumstance of exposure (coded; `02` = occupational accident) |
| `EVOLUCAO` | string | Outcome code: `1`=cure, `2`=**death from notified condition**, `3`=death from other cause, `4`=lost to follow-up, `5`=transfer, `9`=unknown |
| `SIT_TRAB` | string | Work situation at time of exposure |
| `HOSPITAL` | string | Hospitalised: `"1"` = yes, `"2"` = no |

> **EVOLUCAO coding:** `"2"` = death attributable to the intoxication. `"3"` = death from unrelated cause. Total intoxication-related deaths = `EVOLUCAO %in% c("2", "3")` or restrict to `"2"` for specificity.

---

## 4. SIM — Deaths (individual-level)

**File:** `resultados/SIM/sim_iexo_sp_2014_2024.parquet`
**Grain:** one row per death certificate
**Period:** 2014–2024
**Records:** ~6,500
**Source:** DATASUS — SIM (Sistema de Informações sobre Mortalidade)
**Pre-filter:** SP + ICD T36–T65, X40–X49, X60–X69, Y10–Y19 in underlying cause (`CAUSABAS`)

| Variable | Type | Description |
|---|---|---|
| `DTOBITO` | string | Date of death (format `"YYYY-MM-DD"`) |
| `CAUSABAS` | string | Underlying cause of death (ICD-10) |
| `CAUSABAS_O` | string | Original underlying cause as recorded |
| `CODMUNRES` | string | **Municipality of patient's residence** (6-digit IBGE code) |
| `CODMUNOCOR` | string | Municipality of occurrence of death |
| `SEXO` | string | Sex (coded) |
| `IDADEanos` | integer | Age in years (derived) |
| `RACACOR` | string | Race/ethnicity (coded) |
| `ESC2010` | string | Education level (2010 classification) |
| `OCUP` | string | Occupation (CBO code) |
| `ACIDTRAB` | string | Work-related accident indicator |
| `CIRCOBITO` | string | Circumstances of death |
| `ASSISTMED` | string | Medical assistance received |

> Extract year from `DTOBITO` with `substr(DTOBITO, 1, 4)`. Use `CODMUNRES` for municipality of residence.

---

## 5. SISAGUA — Drinking Water Pesticide Monitoring

**File:** `resultados/SISAGUA/sisagua_sp_2014_2024.parquet`
**Grain:** one row per water sample × pesticide analysis
**Period:** 2014–2024
**Records:** ~3,350,000
**Source:** Ministry of Health — SISAGUA (Sistema de Informação de Vigilância da Qualidade da Água para Consumo Humano)

| Variable | Type | Description |
|---|---|---|
| `cod_ibge` | string | 6-digit IBGE municipality code (derived from original 7-digit code) |
| `NO_MUNICIPIO` | string | Municipality name |
| `NU_ANO` | double | Reference year |
| `NU_SEMESTRE` | double | Semester (1 or 2) |
| `DT_COLETA` | string | Sample collection date |
| `PARAMETRO_FINAL` | string | Pesticide compound name (e.g. `"Glifosato"`, `"Atrazina"`) |
| `TIPO_RESULTADO` | string | Result classification: `"NUMERICO"` = quantifiable detection; `"MENOR_LQ"` = below limit of quantification; `"MENOR_LD"` = not detected; `"OUTROS"` = other |
| `RESULTADO_NUM` | double | Numeric concentration (µg/L); `NA` for non-numeric results |
| `VMP` | string | Maximum permitted value (µg/L) per Portaria GM/MS 888/2021 |
| `TP_ABASTECIMENTO` | string | Water supply type |

> **Detection threshold:** restrict to `TIPO_RESULTADO == "NUMERICO"` for quantifiable detections only. `RESULTADO_NUM > VMP` identifies regulatory exceedances.

---

## 6. PAM — Municipal Agricultural Survey

**File:** `resultados/PROD_AGRO/pam_municipio_produto_ano.parquet`
**Grain:** one row per municipality × crop × year
**Period:** 2014–2024
**Source:** IBGE — Pesquisa Agrícola Municipal (SIDRA table 5457)

| Variable | Type | Description |
|---|---|---|
| `cod_ibge` | string | 6-digit IBGE municipality code |
| `nome_municipio` | string | Municipality name with state abbreviation |
| `produto` | string | Crop name. `"Total"` = sum across all crops for that municipality-year |
| `ano` | integer | Reference year |
| `area_colhida_ha` | double | Harvested area (hectares) |
| `area_colhida_pct` | double | Harvested area as % of municipal total |
| `area_plant_ha` | double | Planted/intended harvest area (hectares) |
| `area_plant_pct` | double | Planted area as % of municipal total |
| `qtd_produzida` | double | Quantity produced (**units vary by crop** — consult IBGE PAM metadata) |
| `rend_medio` | double | Average yield (kg/ha); not available for all crops |
| `valor_prod_mil_reais` | double | Production value (thousands BRL, current prices) |
| `valor_prod_pct` | double | Production value as % of municipal total |

> For municipal totals use `filter(produto == "Total")`. Missing values (`NA`) = crop not grown or data suppressed.

---

## 7. Censo Agropecuário 2017 — Municipal Indicators

**File:** `resultados/PROD_AGRO/censo_agro_municipio_2017.parquet`
**Grain:** one row per municipality
**Period:** 2017 (single cross-section — use as fixed covariate)
**Source:** IBGE — Censo Agropecuário 2017, SIDRA tables 6851 (pesticide use) and 6899 (expenditures)

### Pesticide use (SIDRA table 6851)

| Variable | Type | Description |
|---|---|---|
| `cod_ibge` | string | 6-digit IBGE municipality code |
| `nome_municipio` | string | Municipality name |
| `uso_total` | double | Total agricultural establishments |
| `uso_utilizou` | double | Establishments that used pesticides |
| `uso_nao_utilizou` | double | Establishments that did not use pesticides |
| `uso_nao_utilizou_ecologico` | double | Did not use — ecological/environmental reasons |
| `uso_nao_utilizou_outro` | double | Did not use — other reasons |

### Expenditure counts and values (SIDRA table 6899)

Variables follow the pattern `n_estab_<category>` (number of establishments) and `valor_<category>` (spending in thousands BRL). Key categories:

| Suffix | Description |
|---|---|
| `total` | All establishment expenditures |
| `agrotoxicos` | **Pesticide** expenditure (key variable) |
| `adubos_corretivos` | Fertilizers and soil conditioners |
| `sementes_mudas` | Seeds and seedlings |
| `salarios` | Wages paid |
| `combustiveis` | Fuels and lubricants |
| `compra_maquinas` | Machinery and vehicles |

---

## 8. Censo Agropecuário 2017 — Additional Tables

**Files:**
- `resultados/PROD_AGRO/censo_agro_lavoura_2017.parquet` — municipality × temporary crop, variables: `num_estab`, `qtd_produzida`, `qtd_vendida`, `valor_prod_mil_reais`, `valor_venda_mil_reais`, `area_colhida_ha`
- `resultados/PROD_AGRO/censo_agro_agrotox_orientacao_2017.parquet` — municipality × guidance type for pesticide use
- `resultados/PROD_AGRO/censo_agro_manejo_solo_2017.parquet` — municipality × soil management practice
- `resultados/PROD_AGRO/censo_agro_praticas_plantio_2017.parquet` — municipality × planting practice

All fixed to 2017. Use `cod_ibge` to join with other files.

---

## 9. CAGED — Monthly Employment Records (individual-level)

**File:** `resultados/CAGED/CAGED_YYYY_MM.parquet` (one file per month)
**Grain:** one row per employment contract event (hiring or dismissal)
**Period:** 2014–2024 (17 months missing — see METHODS.md §11)
**Source:** Ministry of Labor (MTE) — CAGED
**Pre-filter:** São Paulo state (`uf == "35"`) + CNAE division 01 (agriculture/livestock)

To read all months at once:
```r
library(arrow)
caged <- open_dataset("./resultados/CAGED/") |> collect()
```

| Variable | Type | Description |
|---|---|---|
| `município` | string | MTE 7-digit municipality code. Strip check digit: `substr(município, 1, 6)` to get IBGE code |
| `uf` | string | State code (`"35"` = São Paulo) |
| `saldomovimentação` | integer | Event: `+1` = hiring, `-1` = dismissal, `0` = transfer (post-2020 only); `NA` = unexpected value |
| `cbo2002ocupação` | string | Occupation code (6-digit CBO 2002) |
| `nome_ocupacao` | string | Occupation name (joined from official CBO dictionary) |
| `subclasse` | string | Economic activity subclass (CNAE 2.0, 7 digits) |
| `graudeinstrução` | string | Education level (coded) |
| `idade` | string | Worker age |
| `sexo` | string | Sex (coded) |
| `raçacor` | string | Race/ethnicity (coded) |
| `salário` | string | Monthly wage (BRL) |
| `horascontratuais` | string | Contracted weekly hours |
| `tipoestabelecimento` | string | Establishment type |
| `tipodedeficiência` | string | Disability type |
| `indicadoraprendiz` | string | Apprenticeship indicator |
| `tamestabjan` | string | Establishment size bracket (January reference) |
| `ano_referencia` | integer | Reference year |
| `mes_referencia` | integer | Reference month (1–12) |

> **Format change:** column names and encoding differ between old (≤2019) and new (≥2020) CAGED. The processing script harmonises both formats automatically.

---

## 10. CAGED — Agricultural Employment Aggregate (municipality × year)

**File:** `resultados/contextual/caged_agro_sp_municipio_ano.parquet`
**Grain:** one row per municipality × year
**Period:** 2014–2024
**Source:** aggregated from monthly CAGED parquets (Section 9 of `07_build_outputs.R`)

| Variable | Type | Description |
|---|---|---|
| `cod_ibge` | string | 6-digit IBGE municipality code |
| `ano` | integer | Reference year |
| `caged_admissoes_agro` | integer | Formal agricultural admissions |
| `caged_desligamentos_agro` | integer | Formal agricultural dismissals |
| `caged_saldo_liquido_agro` | integer | Net employment balance |
| `caged_movimentos_total_agro` | integer | Total movements (admissions + dismissals + transfers) |

---

## 11. Population Estimates (municipality × year × sex × age)

**File:** `resultados/contextual/populacao_sp_municipio_ano.parquet`
**Grain:** one row per municipality × year × sex × age group
**Period:** 2014–2024 (filtered from 2001–2025 source)
**Source:** IBGE intercensal population estimates via DATASUS

| Variable | Type | Description |
|---|---|---|
| `cod_ibge` | string | 6-digit IBGE municipality code |
| `ano` | integer | Reference year |
| `sexo` | string | `"Masculino"` or `"Feminino"` |
| `idade` | integer | Single year of age |
| `populacao` | integer | Estimated population count |

> The raw source file at `Bancos/populacao_estimativas_idade_simples_2001_2025.parquet` covers 2001–2025 and all Brazilian states (columns named `ANO`, `CODMUN`, `SEXO`, `IDADE`, `POPULACAO` in uppercase). The processed contextual file is pre-filtered to SP and 2014–2024 with standardised lowercase column names.

---

## 12. Contextual Covariates

### IVS — Social Vulnerability Index

**File:** `resultados/contextual/ivs_municipios_sp_2010.parquet`
**Grain:** multiple rows per municipality (by household situation and weighting area; filter to `label_sit_dom == "Total Situação de Domicílio"` and take the row with maximum population for the overall municipal aggregate)
**Period:** Census 2010
**Source:** IPEA / Atlas do Desenvolvimento Humano

Key variables: `cod_ibge`, `ivs`, `ivs_infraestrutura_urbana`, `ivs_capital_humano`, `ivs_renda_e_trabalho`, `renda_per_capita`, `i_gini`, `t_analf_15m`, `t_sem_agua_esgoto`, `t_sem_lixo`, `t_densidadem2`, `t_mort1`, `espvida`, `t_razdep`, `label_sit_dom`

### IBP — Brazilian Deprivation Index

**File:** `resultados/contextual/ibp_municipios_sp.parquet`
**Grain:** one row per municipality
**Period:** Census 2010
**Source:** CIDACS / Fiocruz

| Variable | Type | Description |
|---|---|---|
| `cod_ibge` | string | 6-digit IBGE municipality code |
| `ibp_n_setores` | integer | Number of census tracts |
| `ibp_deprivation_mean` | double | Population-weighted mean deprivation score |
| `ibp_deprivation_median` | double | Median deprivation score across census tracts |
| `ibp_pct_urban` | double | % census tracts classified as urban |

### IPVS — Paulista Social Vulnerability Index

**File:** `resultados/contextual/ipvs_municipios_sp.parquet`
**Grain:** one row per municipality
**Period:** 2010
**Source:** SEADE-SP

| Variable | Type | Description |
|---|---|---|
| `cod_ibge` | string | 6-digit IBGE municipality code |
| `municipio_nome` | string | Municipality name |
| `ipvs_pct_grupo1` | double | % households: very low vulnerability |
| `ipvs_pct_grupo2` | double | % households: low vulnerability |
| `ipvs_pct_grupo3` | double | % households: medium-low vulnerability |
| `ipvs_pct_grupo4` | double | % households: medium vulnerability |
| `ipvs_pct_grupo5` | double | % households: high vulnerability |
| `ipvs_pct_grupo6` | double | % households: very high vulnerability |

### Urban/Rural Population Split (IBGE Census 2022)

**File:** `resultados/contextual/pop_rural_urb_sp_2022.parquet`
**Grain:** one row per municipality
**Period:** Census 2022 (single cross-section — use as fixed covariate)
**Source:** IBGE — SIDRA table 9923
**Script:** Section 11 of `Scripts/07_build_outputs.R`

| Variable | Type | Description |
|---|---|---|
| `cod_ibge` | string | 6-digit IBGE municipality code |
| `pop_urb_2022` | integer | Urban population (Census 2022) |
| `pop_rur_2022` | integer | Rural population (Census 2022); `NA` for fully urban municipalities |
| `pct_rural_2022` | double | % of population living in rural areas (0–100) |

---

## Appendix A — ICD-10 Codes Used for Intoxication Filtering

Applied consistently across SIH, SINAN, and SIM:

| Range | Category |
|---|---|
| T36–T65 | Poisoning by drugs and non-medicinal substances |
| X40–X49 | Accidental poisoning by and exposure to noxious substances |
| X60–X69 | Intentional self-poisoning (suicide attempt) |
| Y10–Y19 | Poisoning of undetermined intent |

### T60 subcategories (pesticide-specific)

| Code | Description |
|---|---|
| T60.0 | Organophosphate and carbamate insecticides |
| T60.1 | Halogenated insecticides |
| T60.2 | Other insecticides |
| T60.3 | Herbicides and fungicides |
| T60.4 | Rodenticides |
| T60.8 | Other pesticides |
| T60.9 | Pesticide, unspecified |

---

## Appendix B — Municipality Code Conventions

| Source | Code column | Digits | Notes |
|---|---|---|---|
| All contextual/outcome parquets | `cod_ibge` | 6 | Standard join key |
| CAGED monthly parquets | `município` | 7 | Strip with `substr(município, 1, 6)` |
| SISAGUA raw (Bancos/) | `CO_MUNICIPIO_IBGE` | 7 | Strip with `substr(..., 1, 6)` |
| SISAGUA processed (resultados/) | `cod_ibge` | 6 | Already standardised |
| SIH-RD | `MUNIC_RES`, `MUNIC_MOV` | 6 | Use `MUNIC_RES` for patient residence |
| SINAN | `ID_MN_RESI` | 6 | Use for patient residence |
| SIM | `CODMUNRES` | 6 | Use for patient residence |

---

*Data processed and documented by Isaac Schrarstzhaupt (isaacns@usp.br). For questions, contact the project team.*
