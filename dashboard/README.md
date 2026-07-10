# Dashboard — Agrotóxicos & Saúde (SP, 2014–2024)

Local, interactive Shiny prototype for exploring the project data. Runs entirely
on your machine: it reads only the versioned outputs in `resultados/` (no raw
microdata, no server, no network at runtime). Built for internal team use and as
a demo to decide whether to scale to a hosted server later.

## What it does

**Tab "Visão geral"** — the aggregated municipal base (`base_consolidada`, 645
municipalities × 11 years). Pick an indicator (rates, counts, pesticide use,
vulnerability…) and a year to drive: KPI cards, a choropleth map of SP, a
state-level time series, a top-15 ranking, and a searchable table.

**Tab "Microdados"** — drill into the individual-level files (SIH, SINAN, SIM,
SISAGUA). Filter by year range and municipality; see records per year, a
breakdown by a chosen dimension, and a 500-row sample. Big files (SISAGUA, 3.3 M
rows) are filtered lazily on disk via `arrow`, so it stays responsive.

## How to run

From the repo root (with `Agrotoxicos.Rproj` open, so the working directory is correct):

```r
# 1. Install packages (one time). Most are already in the project.
install.packages(c("shiny", "bslib", "plotly", "leaflet", "reactable",
                   "sf", "arrow", "dplyr", "tidyr", "scales", "geobr"))

# 2. Cache the SP map geometry (one time; needs internet just this once).
#    Already committed as dashboard/data/sp_munis.rds — only re-run if missing.
source("dashboard/setup_geo.R")

# 3. Launch.
shiny::runApp("dashboard")
```

In RStudio you can also open `dashboard/app.R` and click **Run App**.

## Notes

- **Data source:** `resultados/base_consolidada_sp_2014_2024.parquet` and the
  individual parquets under `resultados/SIH|SINAN|SIM|SISAGUA/`. Nothing is read
  from `Bancos/`.
- **Rates:** aggregated trends use the state total for counts and the municipal
  median for rates/percentages (labelled on the chart). Municipal values on the
  map and ranking are the raw figures from the base.
- **Missing data:** municipalities without a value (e.g. SISAGUA without
  monitoring) render grey on the map and are excluded from the ranking.
- **Scaling later:** the same code runs unchanged on a Shiny Server / Posit
  Connect if the team decides to host it. No rewrite needed.
