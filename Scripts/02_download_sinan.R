# ===================================================================
## Script para baixar dados de intoxicações exógenas
# ===================================================================
# ===================================================================
## Data da última atualização: 2026-03-11
# ===================================================================
# ===================================================================
## Autor: Isaac Schrarstzhaupt (github/isaacdata) - isaacns@usp.br
# ===================================================================

library(read.dbc)
library(dplyr)   
library(stringr) 
library(arrow)

# Definir os anos e preparar a lista para receber os dados
anos <- 2022
lista_dados <- list()

dir_sinan <- "./Processados/SINAN"
if (!dir.exists(dir_sinan)) dir.create(dir_sinan, recursive = TRUE)

# URLs base
base_finais <- "ftp://ftp.datasus.gov.br/dissemin/publicos/SINAN/DADOS/FINAIS/"
base_prelim <- "ftp://ftp.datasus.gov.br/dissemin/publicos/SINAN/DADOS/PRELIM/"

# Loop para baixar cada ano
for (ano in anos) {
  
  # Pega os últimos 2 dígitos do ano (ex: 2022 -> 22)
  ano_curto <- substr(ano, 3, 4)
  nome_arquivo <- paste0("IEXOBR", ano_curto, ".dbc")
  
  # Caminhos locais e remotos
  dest_local <- file.path(dir_sinan, nome_arquivo)
  url_finais <- paste0(base_finais, nome_arquivo)
  url_prelim <- paste0(base_prelim, nome_arquivo)
  
  sucesso <- FALSE
  
  # Pasta FINAIS
  message(paste("Tentando baixar", ano, "da pasta FINAIS..."))
  try({
    download.file(url_finais, destfile = dest_local, mode = "wb", quiet = TRUE)
    if (file.size(dest_local) > 0) {
      sucesso <- TRUE
      message(" -> Sucesso na pasta FINAIS.")
    }
  }, silent = TRUE)
  
  # Pasta PRELIM (se falhar na FINAIS)
  if (!sucesso) {
    message(paste("Não achou em FINAIS. Tentando baixar", ano, "da pasta PRELIM..."))
    try({
      download.file(url_prelim, destfile = dest_local, mode = "wb", quiet = TRUE)
      if (file.size(dest_local) > 0) {
        sucesso <- TRUE
        message(" -> Sucesso na pasta PRELIM.")
      }
    }, silent = TRUE)
  }
  
  # Ler e armazenar
  if (sucesso) {
    # Lê o DBC
    dados_ano <- read.dbc(dest_local)
    
    # Criar uma coluna para identificar o ano de origem 
    dados_ano$ano_origem <- ano
    
    # Guardar na lista
    lista_dados[[as.character(ano)]] <- dados_ano
    
    # Se tiver pouco espaço, remover o arquivo .dbc do disco para não ocupar espaço (só descomentar)
    # file.remove(dest_local) 
    
  } else {
    warning(paste("ALERTA: Não foi possível baixar o arquivo do ano", ano))
  }
}

if (length(lista_dados) > 0) {
  dados_completos <- bind_rows(lista_dados)
  
  dados_completos <- dados_completos %>%
    mutate(across(where(is.character), ~ iconv(., from = "latin1", to = "UTF-8"))) %>%
    mutate(across(where(is.factor), ~ iconv(as.character(.), from = "latin1", to = "UTF-8")))
  
  print("--- CONCLUÍDO ---")
  print(paste("Total de registros baixados:", nrow(dados_completos)))
  print(table(dados_completos$ano_origem))
  
  # Salvar como parquet
  library(arrow)
  if (!dir.exists("./resultados/SINAN")) dir.create("./resultados/SINAN", recursive = TRUE)
  write_parquet(dados_completos, "./resultados/SINAN/dados_intoxicacoes_exogenas.parquet", compression = "zstd", compression_level = 10)
  
  print("Parquet salvo com sucesso em UTF-8!")
  
} else {
  print("Nenhum dado foi baixado.")
}