# ===================================================================
## Script: CAGED automated download (2014-2024) + CBO dictionary join
##
## Saves one parquet per month in ./resultados/CAGED/
## Each parquet contains ONLY São Paulo state + agricultural sector (CNAE 01).
## This filter (~1-2% of raw data) keeps disk usage manageable.
##
## Automatic resume: months already saved are skipped on re-run.
## saldomovimentação harmonised across old CAGED (≤2019) and new CAGED (≥2020).
# ===================================================================
## Last updated: 2026-05-27
## Author: Isaac Schrarstzhaupt (github/isaacdata) - isaacns@usp.br
# ===================================================================

library(archive)
library(data.table)
library(arrow)

# Increase download timeout: default 60s is too short for large FTP files (~50-100 MB each)
options(timeout = 100)

# ==========================================
# 0. PARAMETERS
# ==========================================
ano_inicio <- 2014
ano_fim    <- 2024

dir_temp      <- "./Processados/CAGED"
dir_resultado <- "./resultados/CAGED"
if (!dir.exists(dir_temp))      dir.create(dir_temp,      recursive = TRUE)
if (!dir.exists(dir_resultado)) dir.create(dir_resultado, recursive = TRUE)

# Column name mapping: old CAGED (2014-2019) → new CAGED column names (2020+)
# saldomovimentação: old format used "Admitidos/Desligados"; new uses "saldomovimentação"
# Internal values are equivalent: +1 = admission, -1 = dismissal
dicionario_colunas <- c(
  "Município"             = "município",
  "UF"                    = "uf",
  "CBO 2002 Ocupação"     = "cbo2002ocupação",
  "CNAE 2.0 Subclas"      = "subclasse",
  "Grau Instrução"        = "graudeinstrução",
  "Idade"                 = "idade",
  "Sexo"                  = "sexo",
  "Raça Cor"              = "raçacor",
  "Qtd Hora Contrat"      = "horascontratuais",
  "Salário Mensal"        = "salário",
  "Tipo Estab"            = "tipoestabelecimento",
  "Tipo Defic"            = "tipodedeficiência",
  "Ind Aprendiz"          = "indicadoraprendiz",
  "Faixa Empr Início Jan" = "tamestabjan",
  "Admitidos/Desligados"  = "saldomovimentação"
)

# ==========================================
# 1. LOAD CBO OCCUPATION DICTIONARY
# ==========================================
cat("Reading CBO occupation dictionary...\n")
df_cbo <- fread("./Bancos/cbo2002-ocupacao.csv",
                encoding = "Latin-1", colClasses = "character", fill = TRUE)
df_cbo <- df_cbo[, 1:2, with = FALSE]
setnames(df_cbo, names(df_cbo), c("codigo_cbo", "nome_ocupacao"))
df_cbo[, codigo_cbo := trimws(codigo_cbo)]
df_cbo <- df_cbo[codigo_cbo != ""]

# ==========================================
# 2. DOWNLOAD FUNCTION
# ==========================================
# Retries up to max_tries times. A valid .7z CAGED file is always several MB;
# if the downloaded file is smaller than min_bytes, the download was truncated.
baixar_caged_ftp <- function(ano, mes, max_tries = 3, min_bytes = 500000) {
  mes_fmt          <- sprintf("%02d", mes)
  nome_arquivo     <- paste0("CAGED_", ano, "_", mes_fmt, ".7z")
  caminho_completo <- file.path(dir_temp, nome_arquivo)

  if (ano <= 2019) {
    url <- paste0("ftp://ftp.mtps.gov.br/pdet/microdados/CAGED/",
                  ano, "/CAGEDEST_", mes_fmt, ano, ".7z")
  } else {
    url <- paste0("ftp://ftp.mtps.gov.br/pdet/microdados/NOVO%20CAGED/",
                  ano, "/", ano, mes_fmt, "/CAGEDMOV", ano, mes_fmt, ".7z")
  }

  for (tentativa in seq_len(max_tries)) {
    status <- tryCatch(
      suppressWarnings(download.file(url, caminho_completo, mode = "wb", quiet = TRUE)),
      error = function(e) -1L
    )
    tamanho <- if (file.exists(caminho_completo)) file.size(caminho_completo) else 0
    if (status == 0 && tamanho >= min_bytes) return(caminho_completo)
    if (tentativa < max_tries) Sys.sleep(10)
  }

  return(NULL)
}

# ==========================================
# 3. BALANCE HARMONISATION FUNCTION
# ==========================================
# Old CAGED (≤2019): "Admitidos/Desligados" → values "1" and "-1"
#   (some releases use "A"/"D" text format; both handled below)
# New CAGED (≥2020): "saldomovimentação"     → values "1", "-1", and "0" (transfers)
# Standardised output: integer -1, 0, +1  (NA for unexpected values)
harmonizar_saldo <- function(x) {
  x <- trimws(x)
  x[x == "A"] <- "1"
  x[x == "D"] <- "-1"
  x_num <- suppressWarnings(as.integer(x))
  x_num[!x_num %in% c(-1L, 0L, 1L)] <- NA_integer_
  x_num
}

# ==========================================
# 4. MAIN LOOP: download → extract → monthly parquet
# ==========================================
cat("\nStarting batch processing. This may take several hours...\n")
cat("Each parquet saves SP agriculture records only (~1-2% of raw data).\n\n")

for (ano in ano_inicio:ano_fim) {
  for (mes in 1:12) {

    mes_fmt    <- sprintf("%02d", mes)
    cat(sprintf("-> %02d/%d... ", mes, ano))

    # Resume: skip months already processed
    parquet_mes <- file.path(dir_resultado, paste0("CAGED_", ano, "_", mes_fmt, ".parquet"))
    if (file.exists(parquet_mes)) {
      cat("[SKIPPED - already processed]\n")
      next
    }

    # Step A: Download
    arquivo_7z <- baixar_caged_ftp(ano, mes)
    if (is.null(arquivo_7z) || !file.exists(arquivo_7z)) {
      cat("[SKIPPED - not found on FTP]\n")
      next
    }

    pasta_temp <- file.path(dir_temp, paste0("temp_", ano, "_", mes_fmt))

    # Steps B-G wrapped in tryCatch so temp files are always cleaned up,
    # even if extraction or reading fails (e.g. corrupt download).
    resultado <- tryCatch({

      # Step B: Extract
      # archive_extract works for most months; some old CAGED .7z files use PPMD8
      # compression that this version of libarchive doesn't support. Fall back to
      # system 7za (p7zip) in that case: brew install p7zip
      dir.create(pasta_temp, showWarnings = FALSE)
      extraido <- tryCatch({
        archive_extract(arquivo_7z, dir = pasta_temp)
        TRUE
      }, error = function(e) {
        # Locate 7za: Homebrew on Apple Silicon installs to /opt/homebrew/bin/
        cmd_7za <- Sys.which("7za")
        if (cmd_7za == "") cmd_7za <- "/opt/homebrew/bin/7za"
        if (!file.exists(cmd_7za)) {
          message("7za not found. Install p7zip: brew install p7zip")
          return(FALSE)
        }
        cmd <- system2(cmd_7za,
                       args = c("x", shQuote(normalizePath(arquivo_7z)),
                                paste0("-o", shQuote(normalizePath(pasta_temp))),
                                "-y"),
                       stdout = FALSE, stderr = FALSE)
        cmd == 0
      })
      if (!extraido) stop("Extraction failed with both archive_extract and 7za")

      arquivo_txt <- list.files(pasta_temp, pattern = "\\.txt$", full.names = TRUE)[1]
      if (is.na(arquivo_txt)) stop("TXT not found after extraction")

      # Step C: Read and harmonise column names
      if (ano <= 2019) {
        df_mes <- fread(arquivo_txt, sep = ";", encoding = "Latin-1",
                        select       = names(dicionario_colunas),
                        colClasses   = "character")
        setnames(df_mes, names(dicionario_colunas), as.character(dicionario_colunas))
      } else {
        df_mes <- fread(arquivo_txt, sep = ";", encoding = "UTF-8",
                        select       = as.character(dicionario_colunas),
                        colClasses   = "character")
      }

      df_mes[, ano_referencia := ano]
      df_mes[, mes_referencia := mes]

      # Step D: Harmonise saldomovimentação → standardised integer
      df_mes[, saldomovimentação := harmonizar_saldo(saldomovimentação)]

      # Step E: Filter to SP + agriculture only (disk space optimisation)
      # uf == "35" = São Paulo state
      # New CAGED (2020+) stores subclasse without leading zero: "0111300" → "111300"
      # Pad to 7 digits before checking CNAE division 01 (agriculture/livestock/services)
      df_mes[, sub7 := formatC(suppressWarnings(as.integer(subclasse)),
                               width = 7, flag = "0", format = "d")]
      df_mes <- df_mes[uf == "35" & substr(sub7, 1, 2) == "01"]
      df_mes[, sub7 := NULL]

      # Step F: Join with CBO dictionary for occupation name
      if (nrow(df_mes) > 0) {
        df_mes[, cbo2002ocupação := sprintf("%06s", cbo2002ocupação)]
        df_mes[, cbo2002ocupação := gsub(" ", "0", cbo2002ocupação)]
        df_mes <- merge(df_mes, df_cbo,
                        by.x = "cbo2002ocupação", by.y = "codigo_cbo",
                        all.x = TRUE)
      }

      # Step G: Save as monthly parquet
      # Empty parquets are saved as markers so resume logic skips them correctly.
      write_parquet(df_mes, parquet_mes, compression = "zstd", compression_level = 10)

      nrow(df_mes)

    }, error = function(e) {
      cat(sprintf("[ERROR: %s]\n", e$message))
      # Save an empty parquet as a permanent failure marker so this month is
      # skipped on future runs instead of retrying a consistently broken file.
      tryCatch(
        write_parquet(
          data.table(ano_referencia = integer(0), mes_referencia = integer(0)),
          parquet_mes, compression = "zstd"
        ),
        error = function(e2) NULL
      )
      NA_integer_
    }, finally = {
      # Always clean up temp files and free RAM, regardless of success or failure
      unlink(pasta_temp, recursive = TRUE)
      if (file.exists(arquivo_7z)) file.remove(arquivo_7z)
      tryCatch({ rm(df_mes); gc() }, error = function(e) NULL)
    })

    if (!is.na(resultado)) {
      cat(sprintf("[OK — %s SP agriculture records]\n", format(resultado, big.mark = ",")))
    }
  }
}

cat("\n======================================================\n")
cat("DONE!\n")
cat("Monthly parquets saved in:", dir_resultado, "\n")
cat("To load all months at once in R:\n")
cat("  open_dataset('./resultados/CAGED/') |> collect()\n")
cat("To build the SP agriculture aggregate, run Section 9 of 07_build_outputs.R\n")
cat("======================================================\n")
