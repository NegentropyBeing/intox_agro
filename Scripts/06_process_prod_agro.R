# ===================================================================
## Script para processar dados de produção agrícola
## Fontes: PAM/IBGE (2014-2024) e Censo Agropecuário 2017
##
## Outputs:
##   resultados/PROD_AGRO/pam_municipio_produto_ano.parquet
##     -> município × produto × ano, com 8 variáveis PAM
##
##   resultados/PROD_AGRO/censo_agro_lavoura_2017.parquet
##     -> município × produto (lavouras temporárias, Censo 2017)
##        com 6 variáveis de produção (T6957)
##
##   resultados/PROD_AGRO/censo_agro_municipio_2017.parquet
##     -> município, indicadores de uso e gastos com agrotóxicos
##        (T6851 + T6899)
# ===================================================================
# ===================================================================
## Data da última atualização: 2026-05-27
# ===================================================================
# ===================================================================
## Autor: Isaac Schrarstzhaupt (github/isaacdata) - isaacns@usp.br
# ===================================================================

library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(arrow)

if (!dir.exists("./resultados/PROD_AGRO")) dir.create("./resultados/PROD_AGRO", recursive = TRUE)

# ==========================================
# FUNÇÕES AUXILIARES
# ==========================================

# "-" = não aplicável, "..." = não disponível no IBGE
limpar_valor_ibge <- function(x) {
  x <- trimws(as.character(x))
  x[x %in% c("-", "...", "X", "")] <- NA
  suppressWarnings(as.numeric(x))
}

#==========================================
# PARTE 1: PAM (T5457) — 2014 a 2024
# ==========================================
# Estrutura de cada aba: skip=4 → linha 1 = nomes das culturas, linhas 2+ = dados
# Colunas: cod_ibge (7 dígitos) | nome_municipio | Total | cultura1 | cultura2 | ...

cat("===== PROCESSANDO PAM (T5457) =====\n")

dir_pam <- "Bancos/pre-consolidados/PROD_AGRO/PAM_IBGE"

arquivos_pam <- c(
  "T5457_pam_area_colh.xlsx"      = "area_colhida_ha",
  "T5457_pam_area_colh_pct.xlsx"  = "area_colhida_pct",
  "T5457_pam_area_plant.xlsx"     = "area_plant_ha",
  "T5457_pam_area_plant_pct.xlsx" = "area_plant_pct",
  "T5457_pam_qtd_prod.xlsx"       = "qtd_produzida",
  "T5457_pam_rend_med.xlsx"       = "rend_medio",
  "T5457_pam_valor_prod.xlsx"     = "valor_prod_mil_reais",
  "T5457_pam_valor_prod_pct.xlsx" = "valor_prod_pct"
)

lista_pam <- list()

for (arquivo in names(arquivos_pam)) {
  nome_var <- arquivos_pam[arquivo]
  caminho  <- file.path(dir_pam, arquivo)

  abas_anos <- excel_sheets(caminho)
  abas_anos <- abas_anos[grepl("\\d{4}$", abas_anos)]

  cat(sprintf("  %s -> %s (%d anos)\n", arquivo, nome_var, length(abas_anos)))

  for (aba in abas_anos) {
    ano <- as.integer(str_extract(aba, "\\d{4}$"))

    df_raw <- tryCatch(
      suppressMessages(read_excel(caminho, sheet = aba, skip = 4, col_names = FALSE)),
      error = function(e) { cat("    ERRO em", aba, ":", e$message, "\n"); NULL }
    )
    if (is.null(df_raw)) next

    # Linha 1 = nomes das culturas; linhas 2+ = dados
    nomes <- as.character(df_raw[1, ])
    nomes[1] <- "cod_ibge"
    nomes[2] <- "nome_municipio"
    nomes[is.na(nomes)] <- paste0("col_", which(is.na(nomes)))
    colnames(df_raw) <- nomes

    df_long <- df_raw[-1, ] |>
      filter(grepl("^\\d{7}$", trimws(cod_ibge))) |>
      pivot_longer(
        cols      = -c(cod_ibge, nome_municipio),
        names_to  = "produto",
        values_to = "valor"
      ) |>
      mutate(
        valor    = limpar_valor_ibge(valor),
        ano      = ano,
        variavel = nome_var
      )

    lista_pam <- append(lista_pam, list(df_long))
  }
}

cat("Empilhando e pivotando PAM...\n")

pam_final <- bind_rows(lista_pam) |>
  pivot_wider(
    id_cols     = c(cod_ibge, nome_municipio, produto, ano),
    names_from  = variavel,
    values_from = valor
  ) |>
  mutate(cod_ibge = substr(as.character(cod_ibge), 1, 6))

cat(sprintf("PAM final: %d linhas x %d colunas\n", nrow(pam_final), ncol(pam_final)))
write_parquet(pam_final, "./resultados/PROD_AGRO/pam_municipio_produto_ano.parquet",
              compression = "zstd", compression_level = 10)
cat("pam_municipio_produto_ano.parquet salvo!\n\n")
rm(lista_pam, pam_final); gc()

# ==========================================
# PARTE 2: CENSO AGRO — T6957 (lavouras temporárias por produto)
# ==========================================
# Estrutura: skip=6 → linha 1 = nomes das culturas, linhas 2+ = dados
# Colunas: cod_ibge | nome_municipio | condicao | grupos | Total | cultura1 | ...
# 6 abas = 6 variáveis de produção

cat("===== PROCESSANDO T6957 (produção por lavoura) =====\n")

dir_censo <- "Bancos/pre-consolidados/PROD_AGRO/CENSO_AGRO_2017"
caminho_6957 <- file.path(dir_censo, "T6957_prod_agr_2017.xlsx")

abas_6957 <- excel_sheets(caminho_6957)
abas_6957 <- abas_6957[abas_6957 != "Notas"]

nome_vars_6957 <- c(
  "num_estab",
  "qtd_produzida",
  "qtd_vendida",
  "valor_prod_mil_reais",
  "valor_venda_mil_reais",
  "area_colhida_ha"
)

lista_6957 <- list()

for (i in seq_along(abas_6957)) {
  aba      <- abas_6957[i]
  nome_var <- nome_vars_6957[i]
  cat(sprintf("  Aba %d/%d: %s\n", i, length(abas_6957), nome_var))

  df_raw <- suppressMessages(read_excel(caminho_6957, sheet = aba, skip = 5, col_names = FALSE))

  nomes <- as.character(df_raw[1, ])
  nomes[1] <- "cod_ibge"
  nomes[2] <- "nome_municipio"
  nomes[3] <- "condicao"
  nomes[4] <- "grupos"
  nomes[is.na(nomes)] <- paste0("col_", which(is.na(nomes)))
  colnames(df_raw) <- nomes

  df_long <- df_raw[-1, ] |>
    filter(grepl("^\\d{7}$", trimws(as.character(cod_ibge)))) |>
    select(-condicao, -grupos) |>
    pivot_longer(
      cols      = -c(cod_ibge, nome_municipio),
      names_to  = "produto",
      values_to = "valor"
    ) |>
    mutate(valor = limpar_valor_ibge(valor), variavel = nome_var)

  lista_6957 <- append(lista_6957, list(df_long))
}

censo_lavoura <- bind_rows(lista_6957) |>
  pivot_wider(
    id_cols     = c(cod_ibge, nome_municipio, produto),
    names_from  = variavel,
    values_from = valor
  ) |>
  mutate(
    cod_ibge = substr(as.character(cod_ibge), 1, 6),
    ano      = 2017L
  )

cat(sprintf("T6957 final: %d linhas x %d colunas\n", nrow(censo_lavoura), ncol(censo_lavoura)))
write_parquet(censo_lavoura, "./resultados/PROD_AGRO/censo_agro_lavoura_2017.parquet",
              compression = "zstd", compression_level = 10)
cat("censo_agro_lavoura_2017.parquet salvo!\n\n")
rm(lista_6957, censo_lavoura); gc()

# ==========================================
# PARTE 3: CENSO AGRO — T6851 + T6899 (uso e gastos por município)
# ==========================================

cat("===== PROCESSANDO T6851 + T6899 (indicadores por município) =====\n")

# Tabela de referência para join: T6957 já tem cod_ibge + nome no mesmo formato das outras tabelas
municipios_ref <- read_parquet("./resultados/PROD_AGRO/censo_agro_lavoura_2017.parquet") |>
  distinct(cod_ibge, nome_municipio)

# -----------------------------------------------------------
# T6851 — Número de estabelecimentos por uso de agrotóxicos
# -----------------------------------------------------------
# skip=10 → dados diretos; nomes das categorias fixos e conhecidos
cat("  Lendo T6851...\n")

nomes_6851 <- c(
  "nome_municipio_uf",
  "uso_total",
  "uso_utilizou",
  "uso_nao_utilizou",
  "uso_nao_utilizou_ecologico",
  "uso_nao_utilizou_outro"
)

df_6851 <- suppressMessages(read_excel(
  file.path(dir_censo, "T6851_estabelecimento_uso_agro.xlsx"),
  sheet = 1, skip = 10, col_names = FALSE
)) |>
  setNames(nomes_6851) |>
  filter(grepl("\\(\\w{2}\\)$", nome_municipio_uf)) |>
  mutate(across(starts_with("uso_"), limpar_valor_ibge)) |>
  rename(nome_municipio = nome_municipio_uf)

# -----------------------------------------------------------
# T6899 — Gastos dos estabelecimentos por tipo de despesa
# 2 abas: número de estabelecimentos (n_estab_*) e valor em mil R$ (valor_*)
# -----------------------------------------------------------
cat("  Lendo T6899...\n")

nomes_base_6899 <- c(
  "nome_municipio_uf", "condicao", "tipo",
  "total", "arrendamento", "contratacao_servicos",
  "salarios", "adubos_corretivos", "sementes_mudas",
  "compra_animais", "agrotoxicos", "medicamentos_animais",
  "sal_racao_suplementos", "transporte_producao", "energia_eletrica",
  "compra_maquinas", "combustiveis", "novas_culturas",
  "formacao_pastagens", "outras_despesas"
)

ler_aba_6899 <- function(caminho, aba, prefixo) {
  nomes <- nomes_base_6899
  nomes[4:length(nomes)] <- paste0(prefixo, "_", nomes[4:length(nomes)])

  suppressMessages(read_excel(caminho, sheet = aba, skip = 6, col_names = FALSE)) |>
    setNames(nomes) |>
    filter(
      grepl("\\(\\w{2}\\)$", nome_municipio_uf),
      condicao == "Total",
      tipo == "Total"
    ) |>
    select(-condicao, -tipo) |>
    mutate(across(starts_with(prefixo), limpar_valor_ibge)) |>
    rename(nome_municipio = nome_municipio_uf)
}

caminho_6899 <- file.path(dir_censo, "T6899_gasto_agrotoxicos.xlsx")
abas_6899    <- excel_sheets(caminho_6899)
abas_6899    <- abas_6899[abas_6899 != "Notas"]

df_6899_nestab <- ler_aba_6899(caminho_6899, abas_6899[1], "n_estab")
df_6899_valor  <- ler_aba_6899(caminho_6899, abas_6899[2], "valor")

# -----------------------------------------------------------
# Juntar T6851 + T6899 e adicionar cod_ibge via Municipios.csv
# -----------------------------------------------------------
cat("  Juntando T6851 + T6899 e adicionando cod_ibge...\n")

censo_municipio <- df_6851 |>
  full_join(df_6899_nestab, by = "nome_municipio") |>
  full_join(df_6899_valor,  by = "nome_municipio") |>
  left_join(municipios_ref, by = "nome_municipio") |>
  select(cod_ibge, nome_municipio, everything()) |>
  mutate(ano = 2017L)

# Diagnóstico: municípios sem cod_ibge (join falhou)
sem_codigo <- censo_municipio |> filter(is.na(cod_ibge))
if (nrow(sem_codigo) > 0) {
  cat(sprintf("  AVISO: %d municípios sem cod_ibge após o join:\n", nrow(sem_codigo)))
  print(sem_codigo$nome_municipio)
} else {
  cat("  Join completo: todos os municípios encontrados.\n")
}

cat(sprintf("Censo municípios final: %d linhas x %d colunas\n",
            nrow(censo_municipio), ncol(censo_municipio)))

write_parquet(censo_municipio, "./resultados/PROD_AGRO/censo_agro_municipio_2017.parquet",
              compression = "zstd", compression_level = 10)
cat("censo_agro_municipio_2017.parquet salvo!\n\n")

# ==========================================
# PART 4: CENSO AGRO — T6852
# Pesticide use x source of technical guidance received
# Structure: 3-row header (rows 8-10), data from row 11 (skip=10)
# 56 cols: municipality + 5 use-groups × 11 orientation types
# ==========================================

cat("===== PROCESSANDO T6852 (uso agrotóxico × orientação técnica) =====\n")

# Column names: group_orientation
groups_6852   <- c("total", "utilizou", "nao_utilizou", "nao_utilizou_nao_usa", "nao_utilizou_nao_precisou")
orients_6852  <- c("total", "recebe", "governo", "propria", "cooperativas",
                   "integradoras", "empresas_privadas", "ong", "sistema_s", "outra", "nao_recebe")
cols_6852 <- c("nome_municipio", as.vector(outer(groups_6852, orients_6852, paste, sep = "_")))

df_6852 <- suppressMessages(
  read_excel(file.path(dir_censo, "T6852_uso_agroto_x_orientação.xlsx"),
             sheet = 1, skip = 10, col_names = FALSE)
) |>
  setNames(cols_6852) |>
  filter(grepl("\\(\\w{2}\\)$", nome_municipio)) |>
  mutate(across(-nome_municipio, limpar_valor_ibge)) |>
  left_join(municipios_ref, by = "nome_municipio") |>
  select(cod_ibge, nome_municipio, everything()) |>
  mutate(ano = 2017L)

cat(sprintf("T6852 final: %d linhas x %d colunas\n", nrow(df_6852), ncol(df_6852)))
write_parquet(df_6852, "./resultados/PROD_AGRO/censo_agro_agrotox_orientacao_2017.parquet",
              compression = "zstd", compression_level = 10)
cat("censo_agro_agrotox_orientacao_2017.parquet salvo!\n\n")
rm(df_6852); gc()

# ==========================================
# PART 5: CENSO AGRO — T6855
# Soil management practices by family farming typology
# Structure: 2-row header (rows 7-8), data from row 9 (skip=8)
# 6 abas = 6 management variables; 9 cols per aba (typology breakdown)
# ==========================================

cat("===== PROCESSANDO T6855 (manejo do solo × tipologia) =====\n")

typology_cols_6855 <- c("nome_municipio", "tipologia_total",
                        "nao_familiar", "familiar_sim",
                        "familiar_pronaf_b", "familiar_pronaf_v",
                        "familiar_nao_pronafiano", "pronamp_sim", "pronamp_nao")

var_names_6855 <- c("nao_preparou_solo", "preparou_solo", "cultivo_convencional",
                    "cultivo_minimo", "plantio_direto_n_estab", "plantio_direto_ha")

lista_6855 <- list()

abas_6855 <- excel_sheets(file.path(dir_censo, "T6855_manejo_tipologia(agri_familiar).xlsx"))
abas_6855 <- abas_6855[abas_6855 != "Notas"]

for (i in seq_along(abas_6855)) {
  nome_var <- var_names_6855[i]
  cat(sprintf("  Aba %d/%d: %s\n", i, length(abas_6855), nome_var))

  df_aba <- suppressMessages(
    read_excel(file.path(dir_censo, "T6855_manejo_tipologia(agri_familiar).xlsx"),
               sheet = abas_6855[i], skip = 8, col_names = FALSE)
  ) |>
    setNames(typology_cols_6855) |>
    filter(grepl("\\(\\w{2}\\)$", nome_municipio)) |>
    mutate(across(-nome_municipio, limpar_valor_ibge),
           variavel = nome_var)

  lista_6855 <- append(lista_6855, list(df_aba))
}

df_6855_wide <- bind_rows(lista_6855) |>
  select(nome_municipio, variavel, tipologia_total) |>
  pivot_wider(names_from = variavel, values_from = tipologia_total) |>
  left_join(municipios_ref, by = "nome_municipio") |>
  select(cod_ibge, nome_municipio, everything()) |>
  mutate(ano = 2017L)

cat(sprintf("T6855 final: %d linhas x %d colunas\n", nrow(df_6855_wide), ncol(df_6855_wide)))
write_parquet(df_6855_wide, "./resultados/PROD_AGRO/censo_agro_manejo_solo_2017.parquet",
              compression = "zstd", compression_level = 10)
cat("censo_agro_manejo_solo_2017.parquet salvo!\n\n")
rm(lista_6855, df_6855_wide); gc()

# ==========================================
# PART 6: CENSO AGRO — T6845
# Planting practices (number of establishments per practice)
# Structure: 2-row header (rows 9-10), data from row 11 (skip=10)
# 11 cols: municipality + 10 practice types
# ==========================================

cat("===== PROCESSANDO T6845 (práticas de plantio) =====\n")

practice_cols_6845 <- c("nome_municipio",
                        "plantio_nivel", "rotacao_culturas", "pousio_descanso",
                        "protecao_encostas", "recuperacao_mata_ciliar",
                        "reflorestamento_nascentes", "estabilizacao_vocorocas",
                        "manejo_florestal", "outra_pratica", "nenhuma_pratica")

df_6845 <- suppressMessages(
  read_excel(file.path(dir_censo, "T6845_pratica_plantio.xlsx"),
             sheet = 1, skip = 10, col_names = FALSE)
) |>
  setNames(practice_cols_6845) |>
  filter(grepl("\\(\\w{2}\\)$", nome_municipio)) |>
  mutate(across(-nome_municipio, limpar_valor_ibge)) |>
  left_join(municipios_ref, by = "nome_municipio") |>
  select(cod_ibge, nome_municipio, everything()) |>
  mutate(ano = 2017L)

cat(sprintf("T6845 final: %d linhas x %d colunas\n", nrow(df_6845), ncol(df_6845)))
write_parquet(df_6845, "./resultados/PROD_AGRO/censo_agro_praticas_plantio_2017.parquet",
              compression = "zstd", compression_level = 10)
cat("censo_agro_praticas_plantio_2017.parquet salvo!\n\n")
rm(df_6845); gc()

cat("===== PROCESSAMENTO PROD_AGRO CONCLUÍDO =====\n")
cat("Outputs em ./resultados/PROD_AGRO/\n")
