# ===================================================================
## Instituto Todos pela Saúde (ITpS)
## P212 - Detecta Sindromes
# ===================================================================
# ===================================================================
## Script para download, agrupamento e salvamento dos dados de estimativas
## populacionais do IBGE, com formatação de idade simples (0, 5, 10, etc.)
## e sexo (masculino/feminino).
# ===================================================================
# ===================================================================
## Data da última atualização: 2026-03-05
# ==================================================================
# ===================================================================
## Autor: Isaac Schrarstzhaupt (github/isaacdata)
# ===================================================================

# Pacotes
library(dplyr)
library(foreign)
library(arrow)

# Função
download_estimativas <- function(year_start = 2000, year_end = 2024, dest_folder = "./Processados/pop_data") {
  
  if (!dir.exists(dest_folder)) {
    dir.create(dest_folder)
  }
  
  if (year_start < 2000 || year_start > 2025) stop("O ano inicial deve estar entre 2000 e 2025.")
  if (year_end < 2000 || year_end > 2025) stop("O ano final deve estar entre 2000 e 2025.")
  if (year_start > year_end) stop("O ano inicial não pode ser maior que o ano final.")
  
  format_year <- function(year) {
    return(substr(year, 3, 4))
  }
  
  years <- seq(year_start, year_end, by = 1)
  base_url <- "ftp://ftp.datasus.gov.br/dissemin/publicos/IBGE/POPSVS/"
  combined_data <- NULL
  
  for (year in years) {
    short_year <- format_year(year)
    zip_file <- paste0("POPSBR", short_year, ".zip")
    zip_url <- paste0(base_url, zip_file)
    local_zip_path <- file.path(dest_folder, zip_file)
    
    tryCatch({
      message("Baixando dados para o ano: ", year)
      download.file(zip_url, local_zip_path, mode = "wb")
      unzip(local_zip_path, exdir = dest_folder)
      
      dbf_file <- file.path(dest_folder, paste0("pop", short_year, ".dbf"))
      
      if (file.exists(dbf_file)) {
        year_data <- foreign::read.dbf(dbf_file, as.is = TRUE)
        
        # Forçar os nomes das colunas para maiúsculo pois de 2001 a 2024 é maiúsculo mas em 2025 é minúsculo
        names(year_data) <- toupper(names(year_data))
        
        # Limpeza e formatação com idade simples
        year_data <- year_data %>%
          mutate(
            # Converte as strings "000", "005" direto para números inteiros 0, 5
            IDADE = suppressWarnings(as.integer(as.character(IDADE))),
            SEXO = case_when(
              SEXO == "1" ~ "Masculino",
              SEXO == "2" ~ "Feminino",
              TRUE ~ NA_character_
            ),
            UF_COD = substr(COD_MUN, 1, 2),
            UF = case_when(
              UF_COD %in% c("11", "12", "13", "14", "15", "16", "17") ~ c("Rondônia", "Acre", "Amazonas", "Roraima", "Pará", "Amapá", "Tocantins")[match(UF_COD, c("11", "12", "13", "14", "15", "16", "17"))],
              UF_COD %in% c("21", "22", "23", "24", "25", "26", "27", "28", "29") ~ c("Maranhão", "Piauí", "Ceará", "Rio Grande do Norte", "Paraíba", "Pernambuco", "Alagoas", "Sergipe", "Bahia")[match(UF_COD, c("21", "22", "23", "24", "25", "26", "27", "28", "29"))],
              UF_COD %in% c("31", "32", "33", "35") ~ c("Minas Gerais", "Espírito Santo", "Rio de Janeiro", "São Paulo")[match(UF_COD, c("31", "32", "33", "35"))],
              UF_COD %in% c("41", "42", "43") ~ c("Paraná", "Santa Catarina", "Rio Grande do Sul")[match(UF_COD, c("41", "42", "43"))],
              UF_COD %in% c("50", "51", "52", "53") ~ c("Mato Grosso do Sul", "Mato Grosso", "Goiás", "Distrito Federal")[match(UF_COD, c("50", "51", "52", "53"))],
              TRUE ~ NA_character_
            ),
            REGIAO = case_when(
              UF %in% c("Rondônia", "Acre", "Amazonas", "Roraima", "Pará", "Amapá", "Tocantins") ~ "Norte",
              UF %in% c("Maranhão", "Piauí", "Ceará", "Rio Grande do Norte", "Paraíba", "Pernambuco", "Alagoas", "Sergipe", "Bahia") ~ "Nordeste",
              UF %in% c("Minas Gerais", "Espírito Santo", "Rio de Janeiro", "São Paulo") ~ "Sudeste",
              UF %in% c("Paraná", "Santa Catarina", "Rio Grande do Sul") ~ "Sul",
              UF %in% c("Mato Grosso do Sul", "Mato Grosso", "Goiás", "Distrito Federal") ~ "Centro-Oeste",
              TRUE ~ NA_character_
            )
          ) %>%
          select(ANO, CODMUN = COD_MUN, UF, REGIAO, IDADE, SEXO, POPULACAO=POP) %>%
          # Manter o group_by por segurança, para garantir que não haja linhas duplicadas no DBF
          group_by(ANO, CODMUN, UF, REGIAO, IDADE, SEXO) %>%
          summarise(POPULACAO = sum(POPULACAO, na.rm = TRUE), .groups = "drop")
        
        combined_data <- bind_rows(combined_data, year_data)
        
      } else {
        warning(paste("Arquivo DBF não encontrado para o ano:", year))
      }
      
      file.remove(local_zip_path)
      
    }, error = function(e) {
      warning(paste("Erro ao processar o ano:", year, "-", e$message))
    })
  }
  
  return(combined_data)
}

# Criar o dataframe com todos os dados de 2001 a 2025
df_populacao_simples <- download_estimativas(year_start = 2001, year_end = 2025)

# Conferências / auditorias:

# 1. Conferir quantidade de municípios por ano
auditoria_geral <- df_populacao_simples %>%
  group_by(ANO) %>%
  summarise(
    QTD_MUNICIPIOS = n_distinct(CODMUN),
    IDADE_MAXIMA = max(IDADE, na.rm = TRUE),
    .groups = "drop"
  )

# 2. Calcular quantas linhas cada município tem por ano
auditoria_linhas <- df_populacao_simples %>%
  group_by(ANO, CODMUN) %>%
  summarise(
    QTD_LINHAS = n(),
    .groups = "drop"
  )

# 2.1. Contar qual é a quantidade "padrão" de linhas que a maioria dos municípios tem em cada ano
padrao_por_ano <- auditoria_linhas %>%
  count(ANO, QTD_LINHAS) %>%
  group_by(ANO) %>%
  slice_max(n, n = 1) %>% 
  rename(LINHAS_ESPERADAS = QTD_LINHAS, MUNICIPIOS_COM_ESSE_PADRAO = n)

# 2.2 Juntar para ver quem está fora do padrão
municipios_esburacados <- auditoria_linhas %>%
  left_join(padrao_por_ano, by = "ANO") %>%
  filter(QTD_LINHAS != LINHAS_ESPERADAS)

# 3. Auditar se tem linhas que existem mas estão com o valor NA (olhar o zero também, mas o zero é possível de existir)
auditoria_valores <- df_populacao_simples %>%
  summarise(
    TOTAL_LINHAS = n(),
    LINHAS_COM_NA = sum(is.na(POPULACAO)),
    LINHAS_COM_ZERO = sum(POPULACAO == 0, na.rm = TRUE),
    POPULACAO_MINIMA = min(POPULACAO, na.rm = TRUE),
    POPULACAO_MAXIMA = max(POPULACAO, na.rm = TRUE)
  )

# Salvar o dataframe em .parquet com alta compressão
write_parquet(df_populacao_simples, "./Bancos/populacao_estimativas_idade_simples_2001_2025.parquet", compression = "zstd", compression_level = 12)
