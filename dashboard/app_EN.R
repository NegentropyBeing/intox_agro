# ==========================================================================
# Pesticides & Health — São Paulo 2014–2024
# Interactive exploratory dashboard (local Shiny prototype) — ENGLISH version
#
# Run:  install once ->  install.packages(c("shiny","bslib","plotly",
#                          "leaflet","reactable","sf","arrow","dplyr",
#                          "tidyr","scales","geobr"))
#       cache geometry ->  Rscript dashboard/setup_geo.R   (one-time)
#       launch (RStudio) ->  open this file and click "Run App"
#       launch (console) ->  shiny::runApp(shiny::shinyAppFile("dashboard/app_EN.R"))
#
# This is the English twin of app.R — identical logic and data, translated UI.
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

# --------------------------------------------------------------------------
# PROJECT ROOT
# shiny::runApp() sets the working directory to dashboard/, so relative paths
# to resultados/ break. Walk up from the current wd until we find the
# consolidated base — works whether launched from the repo root, via runApp(),
# or via RStudio "Run App".
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
       "Open Agrotoxicos.Rproj and run shiny::runApp(shiny::shinyAppFile(\"dashboard/app_EN.R\")).")
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

fmt_num <- function(x) format(round(x), big.mark = ",", decimal.mark = ".")
fmt_dec <- function(x) format(round(x, 1), big.mark = ",", decimal.mark = ".", nsmall = 1)

indicators <- tibble::tribble(
  ~id,                          ~label,                                              ~agg,  ~fmt,
  "taxa_hosp_100k",             "Hospitalizations /100k (all ages)",                 "med", "dec",
  "taxa_hosp_0_14_100k",        "Hospitalizations /100k (ages 0–14)",                "med", "dec",
  "taxa_notif_100k",            "SINAN notifications /100k",                         "med", "dec",
  "taxa_obitos_sim_100k",       "Deaths /100k",                                      "med", "dec",
  "sih_n_hosp",                 "Hospitalizations (count)",                          "sum", "num",
  "sinan_n_notif",              "SINAN notifications (count)",                       "sum", "num",
  "sim_n_obitos",               "Deaths (count)",                                    "sum", "num",
  "censo_pct_uso_agrotox",      "% establishments using pesticides (Ag Census 2017)","med", "dec",
  "sisagua_pct_deteccao",       "% water samples with detection (SISAGUA)",          "med", "dec",
  "pam_area_colhida_ha",        "Harvested area (ha, PAM)",                          "sum", "num",
  "ivs",                        "Social Vulnerability Index (IVS)",                  "med", "dec",
  "pct_rural_2022",             "% rural population (2022 Census)",                  "med", "dec"
)

ind_choices <- setNames(indicators$id, indicators$label)
ind_meta <- function(id) indicators[match(id, indicators$id), ]
ind_fmt  <- function(id, x) if (ind_meta(id)$fmt == "num") fmt_num(x) else fmt_dec(x)

# --------------------------------------------------------------------------
# MICRODATA CONFIG — one entry per source system for the "Microdata" tab.
#   year_expr / cod_expr : how to derive a standard year and 6-digit code
#   lazy = TRUE keeps big files (SISAGUA) on disk via arrow
# --------------------------------------------------------------------------

sys_cfg <- list(
  SIH = list(
    label = "SIH — Hospitalizations", path = "resultados/SIH/sih_iexo_sp_2014_2024.parquet",
    year_col = "ANO_CMPT", cod_col = "MUNIC_RES", lazy = TRUE,
    dims = c("SEXO", "RACA_COR", "MORTE"),
    show = c("N_AIH", "ANO_CMPT", "MUNIC_RES", "DIAG_PRINC", "SEXO", "IDADE", "COD_IDADE", "MORTE", "DIAS_PERM")
  ),
  SINAN = list(
    label = "SINAN — Notifications", path = "resultados/SINAN/sinan_iexo_sp_2014_2024.parquet",
    year_col = "ano_origem", cod_col = "ID_MN_RESI", lazy = TRUE,
    dims = c("CS_SEXO", "CS_RACA", "EVOLUCAO", "AGENTE_TOX"),
    show = c("NU_ANO", "ID_MN_RESI", "NU_IDADE_N", "CS_SEXO", "AGENTE_TOX", "LAVOURA", "EVOLUCAO")
  ),
  SIM = list(
    label = "SIM — Deaths", path = "resultados/SIM/sim_iexo_sp_2014_2024.parquet",
    year_col = NULL, cod_col = "CODMUNRES", lazy = FALSE,   # tiny; derive year from DTOBITO
    dims = c("SEXO", "RACACOR", "CIRCOBITO"),
    show = c("DTOBITO", "CODMUNRES", "CAUSABAS", "SEXO", "IDADEanos", "RACACOR", "CIRCOBITO")
  ),
  SISAGUA = list(
    label = "SISAGUA — Water", path = "resultados/SISAGUA/sisagua_sp_2014_2024.parquet",
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
  title = "Pesticides & Health — SP 2014–2024",
  theme = theme,
  fillable = TRUE,

  # ---- Tab 1: Overview (aggregated municipal base) ----
  nav_panel(
    "Overview",
    layout_sidebar(
      sidebar = sidebar(
        width = 300,
        selectInput("ind", "Indicator", choices = ind_choices),
        sliderInput("ano", "Year (map / ranking / cards)",
                    min = min(anos), max = max(anos), value = max(anos),
                    step = 1, sep = "", animate = TRUE),
        selectizeInput("muni", "Municipalities (filters the page)", multiple = TRUE,
                       choices = sort(unique(base$nome_municipio)),
                       options = list(placeholder = "all")),
        helpText("Municipality × year base (7,095 rows, 73 variables). Fixed covariates",
                 "(Ag Census 2017, IVS 2010, urban/rural 2022) repeat across years.")
      ),
      layout_columns(
        fill = FALSE,
        value_box("Hospitalizations in year", textOutput("kpi_hosp"), theme = "primary"),
        value_box("SINAN notifications", textOutput("kpi_notif"), theme = "secondary"),
        value_box("Deaths", textOutput("kpi_obitos"), theme = "danger"),
        value_box("Municipalities w/ water detection", textOutput("kpi_agua"), theme = "info")
      ),
      layout_columns(
        col_widths = c(6, 6),
        card(card_header(textOutput("map_title")), leafletOutput("map", height = 420)),
        card(card_header(textOutput("trend_title")), plotlyOutput("trend", height = 420))
      ),
      layout_columns(
        col_widths = c(5, 7),
        card(card_header(textOutput("rank_title")), plotlyOutput("rank", height = 380)),
        card(card_header("Table — municipality × year"), reactableOutput("tbl"))
      )
    )
  ),

  # ---- Tab 2: Microdata drill ----
  nav_panel(
    "Microdata",
    layout_sidebar(
      sidebar = sidebar(
        width = 300,
        selectInput("sys", "System", choices = setNames(names(sys_cfg), sapply(sys_cfg, `[[`, "label"))),
        sliderInput("m_anos", "Years", min = min(anos), max = max(anos),
                    value = c(min(anos), max(anos)), step = 1, sep = ""),
        selectizeInput("m_muni", "Municipalities", multiple = TRUE,
                       choices = sort(unique(base$nome_municipio)),
                       options = list(placeholder = "all")),
        uiOutput("dim_ui"),
        helpText("Lazy filtering via arrow — SISAGUA (3.3M rows) is aggregated",
                 "on disk; the table shows a 500-row sample.")
      ),
      layout_columns(
        fill = FALSE,
        value_box("Records in filter", textOutput("m_n"), theme = "primary"),
        value_box("Municipalities", textOutput("m_munis"), theme = "secondary"),
        value_box("Period", textOutput("m_periodo"), theme = "info")
      ),
      layout_columns(
        col_widths = c(6, 6),
        card(card_header("Records per year"), plotlyOutput("m_byyear", height = 320)),
        card(card_header(textOutput("m_dim_title")), plotlyOutput("m_bydim", height = 320))
      ),
      card(card_header("Record sample (500)"), reactableOutput("m_tbl"))
    )
  ),

  nav_spacer(),
  nav_item(tags$span(style = "color:#888;font-size:.85em;",
                     "Local prototype · FSP-USP × University of Michigan"))
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
    if (n == 0) "Time series — state"
    else sprintf("Time series — %d municipality(ies) selected", n)
  })

  output$kpi_hosp   <- renderText(fmt_num(sum(year_slice()$sih_n_hosp, na.rm = TRUE)))
  output$kpi_notif  <- renderText(fmt_num(sum(year_slice()$sinan_n_notif, na.rm = TRUE)))
  output$kpi_obitos <- renderText(fmt_num(sum(year_slice()$sim_n_obitos, na.rm = TRUE)))
  output$kpi_agua   <- renderText(fmt_num(sum(year_slice()$sisagua_pct_deteccao > 0, na.rm = TRUE)))

  output$map_title <- renderText(paste0(ind_meta(input$ind)$label, " — ", input$ano))

  output$map <- renderLeaflet({
    validate(need(!is.null(sp_munis),
                  "Geometry not found. Run once: Rscript dashboard/setup_geo.R"))
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
                                ind_meta(id)$label, ifelse(is.na(val), "no data", ind_fmt(id, val))),
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
    ylab <- if (agg == "sum") "Total" else "Municipal median"
    plot_ly(tr, x = ~ano, y = ~v, type = "scatter", mode = "lines+markers",
            line = list(color = "#1b7837", width = 3), marker = list(color = "#1b7837"),
            hovertemplate = paste0("%{x}: %{y:.1f}<extra></extra>")) |>
      layout(xaxis = list(title = "", dtick = 1),
             yaxis = list(title = ylab), margin = list(t = 10))
  })

  output$rank_title <- renderText(paste0("Top 15 municipalities — ", input$ano))

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
                nome_municipio = colDef(name = "Municipality", minWidth = 140),
                ano = colDef(name = "Year", maxWidth = 70),
                sih_n_hosp = colDef(name = "Hosp."),
                taxa_hosp_100k = colDef(name = "Hosp. rate/100k", format = colFormat(digits = 1)),
                taxa_hosp_0_14_100k = colDef(name = "0–14 rate/100k", format = colFormat(digits = 1)),
                sinan_n_notif = colDef(name = "Notif."),
                sim_n_obitos = colDef(name = "Deaths"),
                censo_pct_uso_agrotox = colDef(name = "% pesticide use", format = colFormat(digits = 1)),
                sisagua_pct_deteccao = colDef(name = "% water detect.", format = colFormat(digits = 1))
              ))
  })

  # ---------- Microdata ----------

  cods_sel <- reactive({
    if (length(input$m_muni) == 0) return(NULL)
    mun_lookup |> filter(nome_municipio %in% input$m_muni) |> pull(cod_ibge)
  })

  # dynamic breakdown-dimension selector, per system
  output$dim_ui <- renderUI({
    selectInput("m_dim", "Break down by", choices = sys_cfg[[input$sys]]$dims)
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
      layout(xaxis = list(title = "", dtick = 1), yaxis = list(title = "records"))
  })

  output$m_dim_title <- renderText(paste("Records by", input$m_dim %||% ""))

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
