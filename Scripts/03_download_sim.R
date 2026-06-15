# ===================================================================
## Script to download SIM (Mortality Information System) data
## for exogenous intoxication deaths — São Paulo state, 2014-2024
##
## Downloads individual-level records via microdatasus, filters by
## ICD codes, and assembles a single parquet file.
##
## Output: resultados/SIM/sim_iexo_sp_2014_2024.parquet
##
## Automatic resume: chunks already saved are skipped on re-run.
# ===================================================================
## Last updated: 2026-05-27
## Author: Isaac Schrarstzhaupt (github/isaacdata) - isaacns@usp.br
# ===================================================================

library(microdatasus)
library(dplyr)
library(readr)
library(arrow)
library(stringr)
library(tidyr)
library(lubridate)
library(purrr)

# --- Parameters ---
anos_sim  <- 2014:2024
ufs_sim   <- c("SP")

# ICD-10 codes for exogenous intoxication (same criteria as SIH and SINAN)
cids_iexo_sim <- c(
  paste0("T", 36:65),
  paste0("X", 40:49),
  paste0("X", 60:69),
  paste0("Y", 10:19)
)

# Relevant columns to retain after process_sim() decoding.
# Uses any_of() so the script doesn't break if a column is absent in a given year.
COLUNAS_SIM <- c(
  "DTOBITO", "CAUSABAS", "CAUSABAS_O",
  "CODMUNRES", "CODMUNOCOR",
  "SEXO", "SEXO_PADRONIZADO",
  "IDADEanos", "IDADE_SIMPLES",
  "RACACOR", "ESC2010",
  "OCUP", "ACIDTRAB",
  "CIRCOBITO", "TPMORTE", "ASSISTMED"
)

# --- Chunk directory ---
dir_chunks_sim <- "./Processados/chunks/sim_intoxicacao_chunks"
if (!dir.exists(dir_chunks_sim)) dir.create(dir_chunks_sim, recursive = TRUE)

if (!dir.exists("./resultados/SIM")) dir.create("./resultados/SIM", recursive = TRUE)

# ===================================================================
# PART 1: DOWNLOAD — one chunk per year (SP only)
# ===================================================================

print("--- STARTING SIM DOWNLOAD ---")

for (ano in anos_sim) {
  for (uf in ufs_sim) {

    chunk_path <- file.path(dir_chunks_sim, paste0("sim_chunk_", uf, "_", ano, ".parquet"))

    if (file.exists(chunk_path)) {
      print(paste("Already exists, skipping:", chunk_path))
      next
    }

    print(paste("===== Downloading SIM:", uf, ano, "====="))

    dados_brutos <- tryCatch({
      fetch_datasus(year_start = ano, year_end = ano, uf = uf,
                   information_system = "SIM-DO")
    }, error = function(e) { print(e$message); return(NULL) })

    if (is.null(dados_brutos)) next

    dados_processados <- process_sim(dados_brutos)

    dados_filtrados <- dados_processados |>
      mutate(CAUSABAS = as.character(CAUSABAS)) |>
      filter(substr(CAUSABAS, 1, 3) %in% cids_iexo_sim)

    if (nrow(dados_filtrados) > 0) {
      print(paste("-->", nrow(dados_filtrados), "records found. Saving chunk."))

      dados_para_salvar <- dados_filtrados |>
        select(any_of(COLUNAS_SIM))

      write_parquet(dados_para_salvar, chunk_path, compression = "zstd")
    } else {
      print("No records found for these ICD codes.")
      # Save empty marker so resume logic skips this year next run
      write_parquet(dados_filtrados[0, ], chunk_path, compression = "zstd")
    }

    rm(dados_brutos, dados_processados, dados_filtrados)
    gc()
    Sys.sleep(1)
  }
}

print("--- DOWNLOAD COMPLETE ---")

# ===================================================================
# PART 2: ASSEMBLE — combine all chunks into a single parquet
# ===================================================================

print("--- ASSEMBLING FINAL PARQUET ---")

sim_final <- open_dataset(dir_chunks_sim, format = "parquet") |>
  collect()

cat("Total records:", nrow(sim_final), "\n")
cat("Columns:", paste(names(sim_final), collapse = ", "), "\n")

# Year from death date for quick temporal checks
if ("DTOBITO" %in% names(sim_final)) {
  cat("Period:\n")
  print(table(substr(as.character(sim_final$DTOBITO), 1, 4), useNA = "always"))
}

write_parquet(sim_final, "./resultados/SIM/sim_iexo_sp_2014_2024.parquet",
              compression = "zstd", compression_level = 10)

cat("Saved: resultados/SIM/sim_iexo_sp_2014_2024.parquet\n")

rm(sim_final); gc()

# ===================================================================
# PART 3 (OPTIONAL): RATE CALCULATION
# Uncomment to calculate age-sex standardised mortality rates.
# Requires: Bancos/populacao_tratada_2022_faixas_oficiais.csv
# Output: resultados/taxas_especificas_intoxicacao_YYYY.csv
#         resultados/taxas_agregadas_intoxicacao_YYYY.csv
# ===================================================================

# breaks_oficiais <- c(-1, 4, 9, 14, 19, 29, 39, 49, 59, 69, 79, Inf)
# labels_oficiais <- c("00 a 04", "05 a 09", "10 a 14", "15 a 19", "20 a 29",
#                      "30 a 39", "40 a 49", "50 a 59", "60 a 69", "70 a 79", "80 ou mais")
#
# ano_taxas <- 2022   # change to desired year
#
# sim_ano <- read_parquet("./resultados/SIM/sim_iexo_sp_2014_2024.parquet") |>
#   filter(substr(as.character(DTOBITO), 1, 4) == as.character(ano_taxas))
#
# obitos <- sim_ano |>
#   filter(!is.na(IDADEanos)) |>
#   mutate(
#     IDADEanos    = as.numeric(IDADEanos),
#     FAIXA_ETARIA = cut(IDADEanos, breaks = breaks_oficiais,
#                        labels = labels_oficiais, right = TRUE, include.lowest = TRUE),
#     SEXO_PADRONIZADO = case_when(
#       SEXO %in% c("Masculino", "M", "1") ~ "Homens",
#       SEXO %in% c("Feminino",  "F", "2") ~ "Mulheres",
#       TRUE ~ NA_character_
#     )
#   ) |>
#   filter(!is.na(FAIXA_ETARIA), !is.na(SEXO_PADRONIZADO)) |>
#   group_by(FAIXA_ETARIA, SEXO = SEXO_PADRONIZADO) |>
#   summarise(NUM_OBITOS = n(), .groups = "drop")
#
# populacao_df <- read_csv2("./Bancos/populacao_tratada_2022_faixas_oficiais.csv")
#
# populacao <- populacao_df |>
#   group_by(FAIXA_ETARIA, SEXO) |>
#   summarise(POPULACAO = sum(POPULACAO, na.rm = TRUE), .groups = "drop")
#
# dados_base <- obitos |>
#   full_join(populacao, by = c("FAIXA_ETARIA", "SEXO")) |>
#   mutate(NUM_OBITOS = replace_na(NUM_OBITOS, 0),
#          TAXA_ESPECIFICA = NUM_OBITOS / POPULACAO * 100000)
#
# write_csv2(dados_base,
#            paste0("./resultados/taxas_especificas_intoxicacao_", ano_taxas, ".csv"))
# cat("Rate tables saved.\n")
