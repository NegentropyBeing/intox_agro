library(DataExplorer)
library(arrow)
library(dplyr)
library(skimr)


df_complete <- read_parquet("resultados/base_consolidada_sp_2014_2024.parquet") # add the path for the file base_consolidada_sp_2014_2024.parquet

# explorring data
names(df_complete) # print and check for columns you want to test for 
skim(df_complete)

# ---------

plot_missing(df_complete)

plot_histogram(df_complete[, c("taxa_hosp_100k","taxa_notif_100k","taxa_obitos_sim_100k")])
plot_qq(df_complete[, c("taxa_hosp_100k","taxa_notif_100k")])

# nothing

exposure_vars <- df_complete |> 
  select(pam_area_colhida_ha, censo_pct_uso_agrotox, censo_valor_agrotox_mil,
         sisagua_pct_deteccao, caged_admissoes_agro, pct_rural_2022)

plot_correlation(exposure_vars, type = "continuous")


# nothing

vuln_vars <- df_complete |>
  select(ivs, ivs_capital_humano, ivs_renda_e_trabalho,
         ibp_deprivation_mean, ipvs_pct_grupo5, ipvs_pct_grupo6,
         t_analf_15m, i_gini, renda_per_capita) |>
  distinct()

plot_correlation(vuln_vars)
plot_prcomp(vuln_vars, variance_cap = 0.9)

# nothing

# create_report(  
# df_complete,  
# y = "t_mort1",  # replace y = "t_mort1" to the column you want to use as y
# config = configure_report( 
# add_plot_bar = FALSE,
# add_plot_intro = TRUE,
# add_plot_missing = TRUE,
# add_plot_correlation = TRUE,
# add_plot_prcomp = TRUE))
# 
# create_report( 
# df_complete, 
# y = "t_analf_15m", # replace y = "t_mort1" to the column you want to use as y
# config = configure_report( 
# add_plot_bar = FALSE, 
# add_plot_intro = TRUE, 
# add_plot_missing = TRUE,
# add_plot_correlation = TRUE, 
# add_plot_prcomp = TRUE))