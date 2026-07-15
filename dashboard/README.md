# Dashboard — Agrotóxicos & Saúde (SP, 2014–2024)

Local, interactive Shiny prototype for exploring the project data. Runs entirely
on your machine: it reads only the versioned outputs in `resultados/` (no raw
microdata, no server, no network at runtime). Built for internal team use, as a
demo to decide whether to scale to a hosted server, and as a source of
**report-ready figures** for the descriptive report.

Two twin apps, identical logic, different language:

- `app.R` — Portuguese UI.
- `app_EN.R` — English UI (same features; numbers in English format).

## What it does

**Tab "Visão geral" / "Overview"** — the aggregated municipal base
(`base_consolidada`, 645 municipalities × 11 years). Pick an indicator (rates,
counts, pesticide use, vulnerability, race/colour…) and a year to drive: KPI
cards, a choropleth map of SP, a time series, a top-15 ranking (its title shows
the selected year), and a searchable table. Selecting one or more
**municipalities filters the whole page** (cards, time series, map, ranking);
unselected municipalities grey out on the map.

**Tab "Relações" / "Relationships"** — descriptive (ecological) relationship
between any two variables at municipality level, for a chosen year:

- a **bivariate 3×3 choropleth** (each variable split into terciles; blue = high
  Y, pink = high X, dark purple = both high), rendered as a static `ggplot` so it
  exports cleanly — use **"Baixar mapa (PNG)"** to drop it into the report;
- a **scatter** of X × Y with a linear trend line;
- **Spearman and Pearson** correlation, plus the number of municipalities in the pair.

Relationships are municipal-level co-distributions — **descriptive, not causal**.

**Tab "Microdados" / "Microdata"** — drill into the individual-level files (SIH,
SINAN, SIM, SISAGUA). Filter by year range and municipality; see records per
year, a breakdown by a chosen dimension, and a 500-row sample. Big files
(SISAGUA, 3.3 M rows) are filtered lazily on disk via `arrow`, so it stays responsive.

## How to run

From the repo root (with `Agrotoxicos.Rproj` open, so the working directory is correct):

```r
# 1. Install packages (one time). Most are already in the project.
install.packages(c("shiny", "bslib", "plotly", "leaflet", "reactable",
                   "sf", "arrow", "dplyr", "tidyr", "scales", "geobr",
                   "ggplot2", "patchwork"))

# 2. Cache the SP map geometry (one time; needs internet just this once).
#    Already committed as dashboard/data/sp_munis.rds — only re-run if missing.
source("dashboard/setup_geo.R")

# 3. Launch (Portuguese).
shiny::runApp("dashboard")
```

In RStudio you can also open `dashboard/app.R` and click **Run App**.

For the **English** version, open `dashboard/app_EN.R` in RStudio and click
**Run App**, or from the console:

```r
shiny::runApp(shiny::shinyAppFile("dashboard/app_EN.R"))
```

Both apps live in the same folder without conflict — `runApp("dashboard")`
always launches the Portuguese `app.R`.

## Notes

- **Data source:** `resultados/base_consolidada_sp_2014_2024.parquet` (73
  variables) and the individual parquets under
  `resultados/SIH|SINAN|SIM|SISAGUA/`. Nothing is read from `Bancos/`.
- **Aggregation:** trends and KPIs use the state total for counts and the
  municipal median for rates/percentages (labelled on the chart). Municipal
  values on the maps and ranking are the raw figures from the base.
- **Small municipalities:** rates for low-population municipalities are volatile
  (small-number noise); the bivariate map bins into terciles, which is more
  robust than raw values, but read the scatter for the precise figures.
- **Missing data:** municipalities without a value (e.g. SISAGUA without
  monitoring) render grey on the maps and are excluded from rankings and correlations.
- **Report figures:** the bivariate map exports as PNG; the `plotly` charts have a
  download button in their toolbar — this is how the dashboard feeds the report.
- **Scaling later:** the same code runs unchanged on a Shiny Server / Posit
  Connect if the team decides to host it. No rewrite needed.
