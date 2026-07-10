# setup_geo.R — ONE-TIME geometry cache for the dashboard
#
# Downloads São Paulo municipality boundaries via geobr, simplifies and
# reprojects them, and saves a compact .rds the app reads offline. Run this
# once (needs internet); afterwards the app never touches the network.
#
#   Rscript dashboard/setup_geo.R      # or source() it in RStudio
#
# Output: dashboard/data/sp_munis.rds  (~1.4 MB, one row per municipality)

suppressMessages({
  library(geobr)
  library(sf)
  library(dplyr)
})

out_dir <- "dashboard/data"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

message("Downloading SP municipalities via geobr (one-time)...")

m <- geobr::read_municipality(code_muni = "SP", year = 2020, showProgress = FALSE)

sp_munis <- m |>
  mutate(cod6 = substr(as.character(code_muni), 1, 6)) |>   # 7-digit -> 6-digit IBGE
  select(cod6, name_muni) |>
  st_transform(4326) |>                                     # WGS84 for leaflet
  st_simplify(dTolerance = 0.001, preserveTopology = TRUE)  # shrink geometry

saveRDS(sp_munis, file.path(out_dir, "sp_munis.rds"))

message(sprintf("Saved %s  (%d municipalities, %.0f KB)",
                file.path(out_dir, "sp_munis.rds"),
                nrow(sp_munis),
                file.info(file.path(out_dir, "sp_munis.rds"))$size / 1024))
