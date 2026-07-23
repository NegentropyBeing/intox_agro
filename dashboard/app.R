# ==========================================================================
# Pesticides & Health — São Paulo 2014–2024
# Interactive exploratory dashboard (local Shiny prototype)
#
# Run:  install once ->  install.packages(c("shiny","bslib","plotly",
#                          "leaflet","reactable","sf","arrow","dplyr",
#                          "tidyr","scales","geobr"))
#       cache geometry ->  Rscript dashboard/setup_geo.R   (one-time)
#       launch        ->  shiny::runApp("dashboard")   (or "Run App" in RStudio)
#
# Reads only versioned outputs in resultados/ — no raw microdata, no network.
# Working directory is assumed to be the repo root (Agrotoxicos.Rproj).
# ==========================================================================

library(shiny)
library(bslib)
library(arrow)
library(dplyr)
library(tidyr)
library(scales)
library(plotly)
library(leaflet)
library(reactable)
library(sf)
library(ggplot2)
library(patchwork)

# --------------------------------------------------------------------------
# PROJECT ROOT
# shiny::runApp("dashboard") sets the working directory to dashboard/, so
# relative paths to resultados/ break. Walk up from the current wd until we
# find the consolidated base — works whether launched from the repo root,
# via runApp(), or via RStudio "Run App".
# --------------------------------------------------------------------------

find_root <- function() {
  d <- normalizePath(getwd(), winslash = "/")
  for (i in 1:6) {
    if (file.exists(file.path(d, "resultados", "base_consolidada_sp_2014_2024.parquet"))) return(d)
    parent <- dirname(d)
    if (parent == d) break
    d <- parent
  }
  stop("Could not locate the repo root (resultados/base_consolidada_sp_2014_2024.parquet). ",
       "Open Agrotoxicos.Rproj and run shiny::runApp(\"dashboard\").")
}
ROOT <- find_root()
rp <- function(...) file.path(ROOT, ...)   # path relative to repo root

# --------------------------------------------------------------------------
# DATA (loaded once at startup)
# --------------------------------------------------------------------------

base <- read_parquet(rp("resultados/base_consolidada_sp_2014_2024.parquet"))

anos <- sort(unique(base$ano))

# cod_ibge -> municipality name lookup (for the microdata tab, which has no names)
mun_lookup <- base |> distinct(cod_ibge, nome_municipio)

# Municipality geometry (offline cache produced by setup_geo.R)
geo_path <- rp("dashboard/data/sp_munis.rds")
sp_munis <- if (file.exists(geo_path)) readRDS(geo_path) else NULL

# --------------------------------------------------------------------------
# INDICATOR CONFIG — the columns exposed on the "Overview" tab.
#   agg = how to summarise across municipalities for the trend line / KPIs
#         "sum"  -> state total (counts)
#         "med"  -> municipal median (rates / percentages / indices)
#   fmt = value formatter
# --------------------------------------------------------------------------

fmt_num <- function(x) format(round(x), big.mark = ".", decimal.mark = ",")
fmt_dec <- function(x) format(round(x, 1), big.mark = ".", decimal.mark = ",", nsmall = 1)

indicators <- tibble::tribble(
  ~id,                          ~label,                                                  ~agg,  ~fmt,
  # --- Desfechos (taxas) ---
  "taxa_hosp_100k",             "Internações /100 mil (todas as idades)",                "med", "dec",
  "taxa_hosp_0_14_100k",        "Internações /100 mil (0–14 anos)",                      "med", "dec",
  "taxa_notif_100k",            "Notificações SINAN /100 mil",                           "med", "dec",
  "taxa_notif_0_14_100k",       "Notificações SINAN /100 mil (0–14 anos)",               "med", "dec",
  "taxa_obitos_sim_100k",       "Óbitos /100 mil",                                       "med", "dec",
  "taxa_obitos_sim_0_14_100k",  "Óbitos /100 mil (0–14 anos)",                           "med", "dec",
  "taxa_letalidade_hosp",       "Letalidade hospitalar (%)",                             "med", "dec",
  "taxa_letalidade_hosp_0_14",  "Letalidade hospitalar 0–14 (%)",                        "med", "dec",
  # --- Desfechos (contagens) ---
  "sih_n_hosp",                 "Internações (contagem)",                                "sum", "num",
  "sinan_n_notif",              "Notificações SINAN (contagem)",                         "sum", "num",
  "sim_n_obitos",               "Óbitos (contagem)",                                     "sum", "num",
  # --- Desfechos pesticida-específicos (contagens; issue #7) ---
  "sih_n_hosp_pesticida",       "Internações por pesticida (contagem)",                  "sum", "num",
  "sinan_n_notif_pesticida",    "Notificações por pesticida (contagem)",                 "sum", "num",
  "sim_n_obitos_pesticida",     "Óbitos por pesticida (contagem)",                       "sum", "num",
  # --- Exposição ---
  "censo_pct_uso_agrotox",      "% estabelec. que usaram agrotóxico (Censo Agro 2017)",  "med", "dec",
  "pam_area_colhida_ha",        "Área colhida (ha, PAM)",                                "sum", "num",
  "sisagua_pct_deteccao",       "% amostras de água com detecção (SISAGUA)",             "med", "dec",
  "caged_saldo_liquido_agro",   "Saldo líquido de emprego agrícola (CAGED)",             "sum", "num",
  # --- Contexto / vulnerabilidade / "quem" ---
  "ivs",                        "Índice de Vulnerabilidade Social (IVS)",                "med", "dec",
  "ibp_deprivation_median",     "Índice de Privação (IBP, mediana)",                     "med", "dec",
  "ipvs_pct_grupo6",            "% no grupo de vulnerab. mais alta (IPVS G6)",           "med", "dec",
  "pct_rural_2022",             "% população rural (Censo 2022)",                        "med", "dec",
  "pct_parda",                  "% população parda (Censo 2022)",                        "med", "dec",
  "pct_preta",                  "% população preta (Censo 2022)",                        "med", "dec",
  "pct_branca",                 "% população branca (Censo 2022)",                       "med", "dec",
  "pct_amarela",                "% população amarela (Censo 2022)",                      "med", "dec",
  "pct_indigena",               "% população indígena (Censo 2022)",                     "med", "dec"
)

ind_choices <- setNames(indicators$id, indicators$label)
ind_meta <- function(id) indicators[match(id, indicators$id), ]
ind_fmt  <- function(id, x) if (ind_meta(id)$fmt == "num") fmt_num(x) else fmt_dec(x)

# --------------------------------------------------------------------------
# BIVARIATE MAP — 3x3 tercile choropleth for the "Relações" tab.
# Rendered as a static ggplot/sf so it exports cleanly into the report.
# Palette: blue (Y) × pink (X) → purple, bilinear with perceptually distinct
# hues so the 9 classes stay legible (keyed "<x>-<y>", 1..3).
# --------------------------------------------------------------------------

biv_pal <- c(
  "1-1" = "#e8e8e8", "2-1" = "#d79797", "3-1" = "#c64646",
  "1-2" = "#97a1d8", "2-2" = "#8e6c95", "3-2" = "#863752",
  "1-3" = "#465ac8", "2-3" = "#464194", "3-3" = "#46285f"
)

# terciles, NA-safe (NA input -> NA group, never a numeric bin)
safe_ntile <- function(v, n = 3) {
  out <- rep(NA_integer_, length(v)); ok <- !is.na(v)
  out[ok] <- dplyr::ntile(v[ok], n); out
}

# df must carry cod_ibge, x, y. Returns a ggplot (map + 3x3 legend inset).
bivariate_map <- function(df, xlab, ylab, year) {
  d <- df |> mutate(xt = safe_ntile(x), yt = safe_ntile(y),
                    cls = ifelse(is.na(xt) | is.na(yt), NA_character_, paste0(xt, "-", yt)))
  mp <- sp_munis |> left_join(d, by = c("cod6" = "cod_ibge"))
  main <- ggplot(mp) +
    geom_sf(aes(fill = cls), color = "white", linewidth = 0.05) +
    scale_fill_manual(values = biv_pal, na.value = "#e0e0e0", guide = "none") +
    labs(title = sprintf("X: %s   |   Y: %s   (%s)", xlab, ylab, year),
         caption = paste("Tercis por variável, dentro do ano. Cinza = sem dado.",
                         "Co-distribuição municipal (ecológica) — descritiva, não causal.")) +
    theme_void(base_size = 13) +
    theme(plot.title = element_text(face = "bold", size = 12),
          plot.caption = element_text(color = "#666", size = 8, hjust = 0))
  leg_df <- expand.grid(x = 1:3, y = 1:3); leg_df$cls <- paste0(leg_df$x, "-", leg_df$y)
  leg <- ggplot(leg_df, aes(x, y, fill = cls)) +
    geom_tile(color = "white") +
    scale_fill_manual(values = biv_pal, guide = "none") +
    labs(x = "X →", y = "Y →") + coord_fixed() +
    theme_minimal(base_size = 9) +
    theme(axis.text = element_blank(), axis.ticks = element_blank(),
          panel.grid = element_blank(),
          axis.title.x = element_text(size = 8), axis.title.y = element_text(size = 8))
  main + inset_element(leg, left = 0.0, bottom = 0.02, right = 0.26, top = 0.28, align_to = "full")
}

# --------------------------------------------------------------------------
# MICRODATA CONFIG — one entry per source system for the "Microdata" tab.
#   year_expr / cod_expr : how to derive a standard year and 6-digit code
#   lazy = TRUE keeps big files (SISAGUA) on disk via arrow
# --------------------------------------------------------------------------

sys_cfg <- list(
  SIH = list(
    label = "SIH — Internações", path = "resultados/SIH/sih_iexo_sp_2014_2024.parquet",
    year_col = "ANO_CMPT", cod_col = "MUNIC_RES", lazy = TRUE,
    dims = c("SEXO", "RACA_COR", "MORTE"),
    show = c("N_AIH", "ANO_CMPT", "MUNIC_RES", "DIAG_PRINC", "SEXO", "IDADE", "COD_IDADE", "MORTE", "DIAS_PERM")
  ),
  SINAN = list(
    label = "SINAN — Notificações", path = "resultados/SINAN/sinan_iexo_sp_2014_2024.parquet",
    year_col = "ano_origem", cod_col = "ID_MN_RESI", lazy = TRUE,
    dims = c("CS_SEXO", "CS_RACA", "EVOLUCAO", "AGENTE_TOX"),
    show = c("NU_ANO", "ID_MN_RESI", "NU_IDADE_N", "CS_SEXO", "AGENTE_TOX", "LAVOURA", "EVOLUCAO")
  ),
  SIM = list(
    label = "SIM — Óbitos", path = "resultados/SIM/sim_iexo_sp_2014_2024.parquet",
    year_col = NULL, cod_col = "CODMUNRES", lazy = FALSE,   # tiny; derive year from DTOBITO
    dims = c("SEXO", "RACACOR", "CIRCOBITO"),
    show = c("DTOBITO", "CODMUNRES", "CAUSABAS", "SEXO", "IDADEanos", "RACACOR", "CIRCOBITO")
  ),
  SISAGUA = list(
    label = "SISAGUA — Água", path = "resultados/SISAGUA/sisagua_sp_2014_2024.parquet",
    year_col = "NU_ANO", cod_col = "cod_ibge", lazy = TRUE,
    dims = c("TIPO_RESULTADO", "PARAMETRO_FINAL"),
    show = c("cod_ibge", "NU_ANO", "PARAMETRO_FINAL", "TIPO_RESULTADO", "RESULTADO_NUM", "VMP", "UNIDADE")
  )
)

# Filter one system to a year range (+ optional municipalities); returns a
# tibble with standard columns .year and .cod6 added. Stays lazy until collect.
read_sys <- function(key, yr_range, cods = NULL) {
  cfg <- sys_cfg[[key]]
  d <- open_dataset(rp(cfg$path))
  if (!cfg$lazy) d <- collect(d)

  if (key == "SIM") {
    d <- d |> mutate(.year = suppressWarnings(as.integer(substr(as.character(DTOBITO), 1, 4))),
                     .cod6 = as.character(.data[[cfg$cod_col]]))
  } else {
    yc <- cfg$year_col; cc <- cfg$cod_col
    d <- d |> mutate(.year = as.integer(.data[[yc]]),
                     .cod6 = as.character(.data[[cc]]))
  }

  d <- d |> filter(.year >= yr_range[1], .year <= yr_range[2])
  if (!is.null(cods) && length(cods) > 0) d <- d |> filter(.cod6 %in% cods)
  d
}

# --------------------------------------------------------------------------
# UI
# --------------------------------------------------------------------------

`%||%` <- function(a, b) if (is.null(a)) b else a

theme <- bs_theme(version = 5, primary = "#1b7837")

ui <- page_navbar(
  title = "Agrotóxicos & Saúde — SP 2014–2024",
  theme = theme,
  fillable = TRUE,

  # ---- Tab 1: Overview (aggregated municipal base) ----
  nav_panel(
    "Visão geral",
    layout_sidebar(
      sidebar = sidebar(
        width = 300,
        selectInput("ind", "Indicador", choices = ind_choices),
        sliderInput("ano", "Ano (mapa / ranking / cartões)",
                    min = min(anos), max = max(anos), value = max(anos),
                    step = 1, sep = "", animate = TRUE),
        selectizeInput("muni", "Municípios (filtra a página)", multiple = TRUE,
                       choices = sort(unique(base$nome_municipio)),
                       options = list(placeholder = "todos")),
        helpText("Base município × ano (7.095 linhas, 104 variáveis). Coberturas fixas",
                 "(Censo Agro 2017, IVS 2010, urbano/rural 2022) repetem por ano.")
      ),
      layout_columns(
        fill = FALSE,
        value_box("Internações no ano", textOutput("kpi_hosp"), theme = "primary"),
        value_box("Notificações SINAN", textOutput("kpi_notif"), theme = "secondary"),
        value_box("Óbitos", textOutput("kpi_obitos"), theme = "danger"),
        value_box("Municípios c/ detecção na água", textOutput("kpi_agua"), theme = "info")
      ),
      layout_columns(
        col_widths = c(6, 6),
        card(card_header(textOutput("map_title")), leafletOutput("map", height = 420)),
        card(card_header(textOutput("trend_title")), plotlyOutput("trend", height = 420))
      ),
      layout_columns(
        col_widths = c(5, 7),
        card(card_header(textOutput("rank_title")), plotlyOutput("rank", height = 380)),
        card(card_header("Tabela — município × ano"), reactableOutput("tbl"))
      )
    )
  ),

  # ---- Tab 2: Relationships (bivariate) ----
  nav_panel(
    "Relações",
    layout_sidebar(
      sidebar = sidebar(
        width = 300,
        selectInput("relx", "Variável X", choices = ind_choices, selected = "censo_pct_uso_agrotox"),
        selectInput("rely", "Variável Y", choices = ind_choices, selected = "taxa_hosp_100k"),
        sliderInput("rel_ano", "Ano", min = min(anos), max = max(anos),
                    value = max(anos), step = 1, sep = "", animate = TRUE),
        downloadButton("dl_map", "Baixar mapa (PNG)", class = "btn-sm"),
        helpText("Relação descritiva (ecológica) entre duas variáveis no grão município.",
                 "Tercis por variável; correlação de Spearman como padrão.")
      ),
      layout_columns(
        fill = FALSE,
        value_box("Municípios no par", textOutput("rel_n"), theme = "primary"),
        value_box("Correlação de Spearman", textOutput("rel_sp"), theme = "secondary"),
        value_box("Correlação de Pearson", textOutput("rel_pe"), theme = "info")
      ),
      layout_columns(
        col_widths = c(7, 5),
        card(card_header("Mapa bivariado (3×3)"), plotOutput("biv_map", height = 460)),
        card(card_header("Dispersão X × Y"), plotlyOutput("rel_scatter", height = 460))
      )
    )
  ),

  # ---- Tab 3: Microdata drill ----
  nav_panel(
    "Microdados",
    layout_sidebar(
      sidebar = sidebar(
        width = 300,
        selectInput("sys", "Sistema", choices = setNames(names(sys_cfg), sapply(sys_cfg, `[[`, "label"))),
        sliderInput("m_anos", "Anos", min = min(anos), max = max(anos),
                    value = c(min(anos), max(anos)), step = 1, sep = ""),
        selectizeInput("m_muni", "Municípios", multiple = TRUE,
                       choices = sort(unique(base$nome_municipio)),
                       options = list(placeholder = "todos")),
        uiOutput("dim_ui"),
        helpText("Filtragem lazy via arrow — o SISAGUA (3,3 M linhas) é",
                 "agregado no disco; a tabela mostra uma amostra de 500 linhas.")
      ),
      layout_columns(
        fill = FALSE,
        value_box("Registros no filtro", textOutput("m_n"), theme = "primary"),
        value_box("Municípios", textOutput("m_munis"), theme = "secondary"),
        value_box("Período", textOutput("m_periodo"), theme = "info")
      ),
      layout_columns(
        col_widths = c(6, 6),
        card(card_header("Registros por ano"), plotlyOutput("m_byyear", height = 320)),
        card(card_header(textOutput("m_dim_title")), plotlyOutput("m_bydim", height = 320))
      ),
      card(card_header("Amostra de registros (500)"), reactableOutput("m_tbl"))
    )
  ),

  nav_spacer(),
  nav_item(tags$span(style = "color:#888;font-size:.85em;",
                     "Protótipo local · FSP-USP × University of Michigan"))
)

# --------------------------------------------------------------------------
# SERVER
# --------------------------------------------------------------------------

server <- function(input, output, session) {

  # ---------- Overview ----------

  # base filtered to the selected municipalities (empty selection = all of SP)
  base_sel <- reactive({
    if (length(input$muni) == 0) return(base)
    base |> filter(nome_municipio %in% input$muni)
  })

  # ...then narrowed to the selected year (drives KPIs, map, ranking)
  year_slice <- reactive(base_sel() |> filter(ano == input$ano))

  output$trend_title <- renderText({
    n <- length(input$muni)
    if (n == 0) "Série temporal — estado"
    else sprintf("Série temporal — %d município(s) selecionado(s)", n)
  })

  output$kpi_hosp   <- renderText(fmt_num(sum(year_slice()$sih_n_hosp, na.rm = TRUE)))
  output$kpi_notif  <- renderText(fmt_num(sum(year_slice()$sinan_n_notif, na.rm = TRUE)))
  output$kpi_obitos <- renderText(fmt_num(sum(year_slice()$sim_n_obitos, na.rm = TRUE)))
  output$kpi_agua   <- renderText(fmt_num(sum(year_slice()$sisagua_pct_deteccao > 0, na.rm = TRUE)))

  output$map_title <- renderText(paste0(ind_meta(input$ind)$label, " — ", input$ano))

  output$map <- renderLeaflet({
    validate(need(!is.null(sp_munis),
                  "Geometria não encontrada. Rode uma vez: Rscript dashboard/setup_geo.R"))
    id <- input$ind
    dat <- sp_munis |>
      left_join(year_slice() |> transmute(cod_ibge, val = .data[[id]]),
                by = c("cod6" = "cod_ibge"))
    pal <- colorNumeric("YlOrRd", domain = dat$val, na.color = "#e0e0e0")
    leaflet(dat) |>
      addProviderTiles(providers$CartoDB.Positron) |>
      addPolygons(
        fillColor = ~pal(val), fillOpacity = 0.8, color = "white", weight = 0.4,
        label = ~lapply(sprintf("<b>%s</b><br>%s: %s", name_muni,
                                ind_meta(id)$label, ifelse(is.na(val), "sem dado", ind_fmt(id, val))),
                        htmltools::HTML),
        highlightOptions = highlightOptions(weight = 2, color = "#333", bringToFront = TRUE)
      ) |>
      addLegend("bottomright", pal = pal, values = ~val, title = NULL, opacity = 0.8)
  })

  output$trend <- renderPlotly({
    id <- input$ind; agg <- ind_meta(id)$agg
    tr <- base_sel() |>
      group_by(ano) |>
      summarise(v = if (agg == "sum") sum(.data[[id]], na.rm = TRUE)
                     else median(.data[[id]], na.rm = TRUE), .groups = "drop")
    ylab <- if (agg == "sum") "Total" else "Mediana municipal"
    plot_ly(tr, x = ~ano, y = ~v, type = "scatter", mode = "lines+markers",
            line = list(color = "#1b7837", width = 3), marker = list(color = "#1b7837"),
            hovertemplate = paste0("%{x}: %{y:.1f}<extra></extra>")) |>
      layout(xaxis = list(title = "", dtick = 1),
             yaxis = list(title = ylab), margin = list(t = 10))
  })

  output$rank_title <- renderText(paste0("Top 15 municípios — ", input$ano))

  output$rank <- renderPlotly({
    id <- input$ind
    rk <- year_slice() |>
      filter(!is.na(.data[[id]])) |>
      arrange(desc(.data[[id]])) |>
      slice_head(n = 15) |>
      mutate(nome_municipio = factor(nome_municipio, levels = rev(nome_municipio)))
    plot_ly(rk, x = as.formula(paste0("~", id)), y = ~nome_municipio,
            type = "bar", orientation = "h", marker = list(color = "#1b7837"),
            hovertemplate = "%{y}: %{x}<extra></extra>") |>
      layout(xaxis = list(title = ""), yaxis = list(title = ""),
             margin = list(l = 10, t = 10))
  })

  output$tbl <- renderReactable({
    hl <- input$muni
    d <- base |>
      select(nome_municipio, ano, sih_n_hosp, taxa_hosp_100k, taxa_hosp_0_14_100k,
             sinan_n_notif, sim_n_obitos, censo_pct_uso_agrotox, sisagua_pct_deteccao)
    if (length(hl) > 0) d <- d |> filter(nome_municipio %in% hl)
    reactable(d, searchable = TRUE, striped = TRUE, compact = TRUE,
              defaultPageSize = 10, defaultSorted = list(ano = "desc"),
              columns = list(
                nome_municipio = colDef(name = "Município", minWidth = 140),
                ano = colDef(name = "Ano", maxWidth = 70),
                sih_n_hosp = colDef(name = "Intern."),
                taxa_hosp_100k = colDef(name = "Tx int./100k", format = colFormat(digits = 1)),
                taxa_hosp_0_14_100k = colDef(name = "Tx 0–14/100k", format = colFormat(digits = 1)),
                sinan_n_notif = colDef(name = "Notif."),
                sim_n_obitos = colDef(name = "Óbitos"),
                censo_pct_uso_agrotox = colDef(name = "% uso agrotóx.", format = colFormat(digits = 1)),
                sisagua_pct_deteccao = colDef(name = "% detec. água", format = colFormat(digits = 1))
              ))
  })

  # ---------- Relationships (bivariate) ----------

  rel_data <- reactive({
    base |>
      filter(ano == input$rel_ano) |>
      transmute(cod_ibge, nome_municipio,
                x = .data[[input$relx]], y = .data[[input$rely]])
  })

  rel_stats <- reactive({
    d <- rel_data() |> filter(!is.na(x), !is.na(y))
    list(n = nrow(d),
         sp = if (nrow(d) > 2) cor(d$x, d$y, method = "spearman") else NA_real_,
         pe = if (nrow(d) > 2) cor(d$x, d$y, method = "pearson")  else NA_real_)
  })

  cor_fmt <- function(x) if (is.na(x)) "—" else formatC(x, format = "f", digits = 2)
  output$rel_n  <- renderText(fmt_num(rel_stats()$n))
  output$rel_sp <- renderText(cor_fmt(rel_stats()$sp))
  output$rel_pe <- renderText(cor_fmt(rel_stats()$pe))

  output$biv_map <- renderPlot({
    validate(need(!is.null(sp_munis),
                  "Geometria não encontrada. Rode uma vez: Rscript dashboard/setup_geo.R"))
    bivariate_map(rel_data(), ind_meta(input$relx)$label, ind_meta(input$rely)$label, input$rel_ano)
  }, res = 96)

  output$rel_scatter <- renderPlotly({
    d <- rel_data() |> filter(!is.na(x), !is.na(y))
    xlab <- ind_meta(input$relx)$label; ylab <- ind_meta(input$rely)$label
    p <- plot_ly(d, x = ~x, y = ~y, type = "scatter", mode = "markers",
                 marker = list(color = "#5a9178", size = 6, opacity = 0.6),
                 text = ~nome_municipio,
                 hovertemplate = "%{text}<br>%{x}, %{y}<extra></extra>")
    if (nrow(d) > 2) {
      fit <- lm(y ~ x, data = d); xr <- range(d$x)
      pr <- predict(fit, newdata = data.frame(x = xr))
      p <- p |> add_trace(x = xr, y = pr, type = "scatter", mode = "lines",
                          line = list(color = "#2a5a5b", width = 2),
                          hoverinfo = "skip", showlegend = FALSE, inherit = FALSE)
    }
    p |> layout(xaxis = list(title = xlab), yaxis = list(title = ylab),
                margin = list(t = 10), showlegend = FALSE)
  })

  output$dl_map <- downloadHandler(
    filename = function() sprintf("bivariate_%s_%s_%s.png", input$relx, input$rely, input$rel_ano),
    content = function(file) {
      ggsave(file, plot = bivariate_map(rel_data(), ind_meta(input$relx)$label,
                                        ind_meta(input$rely)$label, input$rel_ano),
             width = 9, height = 7, dpi = 200, bg = "white")
    }
  )

  # ---------- Microdata ----------

  cods_sel <- reactive({
    if (length(input$m_muni) == 0) return(NULL)
    mun_lookup |> filter(nome_municipio %in% input$m_muni) |> pull(cod_ibge)
  })

  # dynamic breakdown-dimension selector, per system
  output$dim_ui <- renderUI({
    selectInput("m_dim", "Quebrar por", choices = sys_cfg[[input$sys]]$dims)
  })

  # filtered data (collected once per change); big systems aggregated lazily
  m_data <- reactive({
    req(input$sys)
    read_sys(input$sys, input$m_anos, cods_sel())
  })

  m_stats <- reactive({
    d <- m_data()
    # summaries computed lazily then collected
    n_tot <- d |> summarise(n = n()) |> collect() |> pull(n)
    n_mun <- d |> summarise(n = n_distinct(.cod6)) |> collect() |> pull(n)
    list(n = n_tot, munis = n_mun)
  })

  output$m_n       <- renderText(fmt_num(m_stats()$n))
  output$m_munis   <- renderText(fmt_num(m_stats()$munis))
  output$m_periodo <- renderText(paste(input$m_anos[1], "–", input$m_anos[2]))

  output$m_byyear <- renderPlotly({
    d <- m_data() |> count(.year) |> collect() |> arrange(.year)
    plot_ly(d, x = ~.year, y = ~n, type = "bar", marker = list(color = "#1b7837"),
            hovertemplate = "%{x}: %{y}<extra></extra>") |>
      layout(xaxis = list(title = "", dtick = 1), yaxis = list(title = "registros"))
  })

  output$m_dim_title <- renderText(paste("Registros por", input$m_dim %||% ""))

  output$m_bydim <- renderPlotly({
    req(input$m_dim)
    dim <- input$m_dim
    d <- m_data() |> count(.data[[dim]]) |> collect() |>
      arrange(desc(n)) |> slice_head(n = 15)
    names(d)[1] <- "cat"
    d <- d |> mutate(cat = factor(as.character(cat), levels = rev(as.character(cat))))
    plot_ly(d, x = ~n, y = ~cat, type = "bar", orientation = "h",
            marker = list(color = "#762a83"),
            hovertemplate = "%{y}: %{x}<extra></extra>") |>
      layout(xaxis = list(title = ""), yaxis = list(title = ""), margin = list(l = 10))
  })

  output$m_tbl <- renderReactable({
    cfg <- sys_cfg[[input$sys]]
    d <- m_data() |> head(500) |> collect()
    keep <- intersect(cfg$show, names(d))
    reactable(d |> select(all_of(keep)), searchable = TRUE, striped = TRUE,
              compact = TRUE, defaultPageSize = 12, wrap = FALSE)
  })
}

shinyApp(ui, server)
