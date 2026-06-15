# ===================================================================
## Script para baixar dados do SIH-RD e salvar em parquet 
## para depois fazer merge com CNES
# ===================================================================
# ===================================================================
## Data da última atualização: 2026-03-11
# ===================================================================
# ===================================================================
## Autor: Isaac Schrarstzhaupt (github/isaacdata) - isaacns@usp.br
# ===================================================================

# Carregar pacotes necessários
library(microdatasus)
library(dplyr)
library(readr)
library(tidyverse) 
library(vroom)  
library(lubridate) 
library(foreign) 
library(arrow)
library(stringr) 

# Lista de UFs 
ufs_brasil <- c("AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS", "MG", "PA", "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", "RR", "SC", "SP", "SE", "TO")
ufs_para_processar <- ufs_brasil 

# Ano(s) de interesse
ano_alvo <- 2022

# Meses de interesse
mes_inicio <- 1 
mes_fim <- 12  

# Definir CIDs de Interesse (Intoxicação exógena)
cids_T <- paste0("T", 36:65) # Intoxicação por medicamentos e substâncias não medicinais
cids_X_acidental <- paste0("X", 40:49) # Envenenamento acidental
cids_X_intencional <- paste0("X", 60:69) # Auto-intoxicação (tentativa de suicídio)
cids_Y <- paste0("Y", 10:19) # Envenenamento de intenção indeterminada

todos_cids_intoxicacao <- c(cids_T, cids_X_acidental, cids_X_intencional, cids_Y)

print("CIDs de interesse (Intoxicação Exógena):")
print(todos_cids_intoxicacao)

# Nome da coluna de CID no SIH-RD 
coluna_cid_sih_rd <- "DIAG_PRINC" 

# Diretório de saída
diretorio_saida_chunks_sih_cid <- "./Processados/chunks/sih_rd_filtrados_cid_chunks" 
if (!dir.exists(diretorio_saida_chunks_sih_cid)) {
  dir.create(diretorio_saida_chunks_sih_cid, recursive = TRUE) 
  print(paste("Pasta criada:", diretorio_saida_chunks_sih_cid))
} else {
  print(paste("Pasta de saída já existe:", diretorio_saida_chunks_sih_cid))
}

# Loop Otimizado para Estados e Meses - SIH-RD (FILTRANDO POR CID) ---

# Loop externo: Estados
for (uf_atual in ufs_para_processar) {
  print(paste("===== INICIANDO SIH-RD (Intoxicação) UF:", uf_atual, "====="))
  
  # Loop interno: Meses
  for (mes_atual in mes_inicio:mes_fim) {
    mes_formatado <- sprintf("%02d", mes_atual)
    print(paste("--- SIH-RD (Intoxicação): Baixando e Filtrando:", uf_atual, "-", ano_alvo, "/", mes_formatado, "---"))
    
    dados_mes_bruto_sih <- tryCatch({
      fetch_datasus(
        year_start = ano_alvo, year_end = ano_alvo,
        month_start = mes_atual, month_end = mes_atual,   
        uf = uf_atual, 
        information_system = "SIH-RD" 
      )
    }, error = function(e) {
      print(paste("ERRO ao baixar dados SIH-RD para", uf_atual, "-", ano_alvo, "/", mes_formatado, ":", e$message))
      return(NULL) 
    })
    
    if (!is.null(dados_mes_bruto_sih) && nrow(dados_mes_bruto_sih) > 0) {
      
      print(paste("SIH-RD: Download concluído. Filtrando por CIDs de interesse..."))
      
      # Filtrar pela coluna DIAG_PRINC usando substr e a lista de CIDs >>>
      dados_filtrados_mes_sih <- dados_mes_bruto_sih %>%
        mutate(!!coluna_cid_sih_rd := as.character(.data[[coluna_cid_sih_rd]])) %>%
        filter(substr(.data[[coluna_cid_sih_rd]], 1, 3) %in% todos_cids_intoxicacao) 
      
      if (nrow(dados_filtrados_mes_sih) > 0) {
        print(paste("SIH-RD (Intoxicação): Encontradas", nrow(dados_filtrados_mes_sih), "linhas para UF:", uf_atual, "Mês:", mes_formatado))
        
        uf_para_nome <- uf_atual       
        ano_para_nome <- ano_alvo      
        mes_para_nome <- mes_formatado 
        
        nome_arquivo_base <- paste0("sih_rd_cid_filtrado_", uf_para_nome, "_", ano_para_nome, "_", mes_para_nome)
        nome_arquivo_parquet <- file.path(diretorio_saida_chunks_sih_cid, paste0(nome_arquivo_base, ".parquet"))
        
        print(paste("--> Salvando chunk SIH-RD como:", nome_arquivo_parquet)) 
        
        tryCatch({
          write_parquet(dados_filtrados_mes_sih, nome_arquivo_parquet) 
        }, error = function(e){
          print(paste("ERRO AO SALVAR o arquivo SIH-RD:", nome_arquivo_parquet))
          print(e$message)
        })
        
      } else {
        print(paste("SIH-RD: Nenhum CID de interesse encontrado para UF:", uf_atual, "Mês:", mes_formatado))
      }
      
      rm(dados_mes_bruto_sih) 
      if (exists("dados_filtrados_mes_sih")) rm(dados_filtrados_mes_sih) 
      
    } else if (is.null(dados_mes_bruto_sih)) {
    } else {
      if (exists("dados_mes_bruto_sih")) rm(dados_mes_bruto_sih) 
    }
    
    print("Executando gc()...")
    gc() 
    Sys.sleep(1) 
    
  } 
  print(paste("===== SIH-RD UF:", uf_atual, "CONCLUÍDA ====="))
} 

print("<<<<< DOWNLOADS, FILTRAGENS E SALVAMENTO DOS CHUNKS SIH-RD CONCLUÍDOS >>>>>")

# Preparação dos dados auxiliares (CNES) 

# Ler arquivo Municipios.csv
print("Lendo arquivo de Municípios...")
municipios <- read.csv2("./Bancos/Municipios.csv", sep = ";", fileEncoding = "UTF-8") 

# Ler arquivo CNES e preparar dataframe CNES
print("Lendo e preparando dados do CNES...")
tbEstabelecimento202601 <- read.csv("./Bancos/CNES/tbEstabelecimento202601.csv",sep=";",fileEncoding = "ISO-8859-1")

# Manter apenas as colunas de interesse
tbEstabelecimento202601 <- tbEstabelecimento202601 %>%
  select(CO_CNES, NO_RAZAO_SOCIAL, NU_LATITUDE, NU_LONGITUDE, CO_MUNICIPIO_GESTOR)

# Merge do CNES com os Municípios
CNES <- merge(tbEstabelecimento202601, municipios, by.x = "CO_MUNICIPIO_GESTOR", by.y = "Cod_IBGE_Mun", all.x = TRUE)

# No dataframe CNES, preencher o campo CO_CNES com zeros à esquerda até 7 caracteres
CNES <- CNES %>%
  mutate(CO_CNES = str_pad(CO_CNES, width = 7, pad = "0"))

# --- PROCESSAMENTO FINAL COM ARROW (Leitura dos Chunks e Merges) ---

print("Abrindo dataset SIH-RD (Intoxicação) com Arrow...")
if (!dir.exists(diretorio_saida_chunks_sih_cid) || length(list.files(diretorio_saida_chunks_sih_cid)) == 0) {
  stop(paste("Pasta de chunks SIH-RD está vazia ou não existe:", diretorio_saida_chunks_sih_cid))
}
dataset_sih_rd_cid <- open_dataset(diretorio_saida_chunks_sih_cid, format = "parquet")

print("Schema original SIH-RD (Intoxicação):")
print(schema(dataset_sih_rd_cid))

# Join 1: Adicionar dados do CNES (Para ter nome do hospital e latitude/longitude)
coluna_cnes_sih <- "CNES" 
coluna_cnes_cnes_df <- "CO_CNES" 

print("Preparando Join SIH-RD com CNES...")
dataset_final_enriquecido_sih_cid <- dataset_sih_rd_cid %>%
  mutate(!!coluna_cnes_sih := as.character(.data[[coluna_cnes_sih]])) %>% 
  left_join(CNES, by = setNames(coluna_cnes_cnes_df, coluna_cnes_sih))

# Salvar o Resultado Final SIH-RD Enriquecido como Parquet 
arquivo_final_sih_cid_parquet <- "./resultados/SIH/sih_rd_intoxicacao_final.parquet"
if (!dir.exists(dirname(arquivo_final_sih_cid_parquet))) dir.create(dirname(arquivo_final_sih_cid_parquet), recursive=TRUE)

print(paste("Executando joins e salvando resultado final SIH-RD em:", arquivo_final_sih_cid_parquet))
tryCatch({
  write_parquet(dataset_final_enriquecido_sih_cid, arquivo_final_sih_cid_parquet, compression = "zstd", compression_level = 10)
  print("Arquivo final SIH-RD (Intoxicação) salvo com sucesso como Parquet!")
}, error = function(e){
  print("ERRO ao salvar o arquivo final SIH-RD:")
  print(e$message)
})

print("--- Processamento SIH-RD Intoxicação concluído ---")

