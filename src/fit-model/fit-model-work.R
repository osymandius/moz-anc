library(naomi)
library(TMB)
library(sf)
library(dfertility)
library(tidyverse)
library(Matrix)

iso3 <- "MOZ"

population <- read.csv("~/Documents/GitHub/fertility_orderly/archive/moz_data_population/20201130-094019-f924623c/moz_population_nso.csv")
areas <- read_sf("~/Documents/GitHub/fertility_orderly/archive/moz_data_areas/20201112-144347-48e53ce9/moz_areas.geojson")
asfr <- read.csv("~/Documents/GitHub/fertility_orderly/archive/moz_asfr/20201204-141436-7f9b7a9d/moz_asfr.csv")


mf <- make_model_frames_dev(iso3, population, asfr,  areas, naomi_level =2, project=2020)

TMB::compile("global/relaxed_eta2.cpp")               # Compile the C++ file
dyn.load(dynlib("global/relaxed_eta2"))

tmb_int <- list()

tmb_int$data <- list(
  M_naomi_obs = mf$M_naomi_obs,
  M_full_obs = mf$M_full_obs,
  X_tips_dummy = mf$Z$X_tips_dummy,
  # X_urban_dummy = mf$Z$X_urban_dummy,
  X_extract_dhs = mf$X_extract$X_extract_dhs,
  X_extract_ais = mf$X_extract$X_extract_ais,
  X_extract_mics = mf$X_extract$X_extract_mics,
  # Z_tips = mf$Z$Z_tips,
  Z_tips_dhs = mf$Z$Z_tips_dhs,
  Z_tips_ais = mf$Z$Z_tips_ais,
  Z_age = mf$Z$Z_age,
  Z_period = mf$Z$Z_period,
  Z_spatial = mf$Z$Z_spatial,
  Z_interaction1 = sparse.model.matrix(~0 + id.interaction1, mf$mf_model),
  Z_interaction2 = sparse.model.matrix(~0 + id.interaction2, mf$mf_model),
  Z_interaction3 = sparse.model.matrix(~0 + id.interaction3, mf$mf_model),
  Z_country = mf$Z$Z_country,
  Z_omega1 = sparse.model.matrix(~0 + id.omega1, mf$mf_model),
  Z_omega2 = sparse.model.matrix(~0 + id.omega2, mf$mf_model),
  R_tips = mf$R$R_tips,
  R_age = mf$R$R_age,
  R_period = mf$R$R_period,
  R_spatial = mf$R$R_spatial,
  R_country = mf$R$R_country,
  rankdef_R_spatial = 1,
  
  log_offset_naomi = log(mf$observations$naomi_level_obs$pys),
  births_obs_naomi = mf$observations$naomi_level_obs$births,
  
  log_offset_dhs = log(filter(mf$observations$full_obs, survtype == "DHS")$pys),
  births_obs_dhs = filter(mf$observations$full_obs, survtype == "DHS")$births,
  
  log_offset_ais = log(filter(mf$observations$full_obs, survtype %in% c("AIS", "MIS"))$pys),
  births_obs_ais = filter(mf$observations$full_obs, survtype %in% c("AIS", "MIS"))$births,
  
  pop = mf$mf_model$population,
  # A_asfr_out = mf$out$A_asfr_out,
  A_tfr_out = mf$out$A_tfr_out,
  
  A_full_obs = mf$observations$A_full_obs,
  
  mics_toggle = mf$mics_toggle,
  
  X_spike_2000_dhs = model.matrix(~0 + spike_2000, mf$observations$full_obs %>% filter(survtype == "DHS")),
  X_spike_1999_dhs = model.matrix(~0 + spike_1999, mf$observations$full_obs %>% filter(survtype == "DHS")),
  X_spike_2001_dhs = model.matrix(~0 + spike_2001, mf$observations$full_obs %>% filter(survtype == "DHS")),
  
  X_spike_2000_ais = model.matrix(~0 + spike_2000, mf$observations$full_obs %>% filter(survtype %in% c("AIS", "MIS"))),
  X_spike_1999_ais = model.matrix(~0 + spike_1999, mf$observations$full_obs %>% filter(survtype %in% c("AIS", "MIS"))),
  X_spike_2001_ais = model.matrix(~0 + spike_2001, mf$observations$full_obs %>% filter(survtype %in% c("AIS", "MIS")))
  
  # out_toggle = mf$out_toggle
  # A_obs = mf$observations$A_obs,
)

tmb_int$par <- list(
  beta_0 = 0,
  
  beta_tips_dummy = rep(0, ncol(mf$Z$X_tips_dummy)),
  # # beta_urban_dummy = rep(0, ncol(X_urban_dummy)),
  u_tips = rep(0, ncol(mf$Z$Z_tips_dhs)),
  log_prec_rw_tips = 0,
  
  u_age = rep(0, ncol(mf$Z$Z_age)),
  log_prec_rw_age = 0,
  
  # u_country = rep(0, ncol(mf$Z$Z_country)),
  # log_prec_country = 0,
  
  omega1 = array(0, c(ncol(mf$R$R_country), ncol(mf$Z$Z_age))),
  log_prec_omega1 = 0,
  lag_logit_omega1_phi_age = 0,
  
  omega2 = array(0, c(ncol(mf$R$R_country), ncol(mf$Z$Z_period))),
  log_prec_omega2 = 0,
  lag_logit_omega2_phi_period = 0,
  
  u_period = rep(0, ncol(mf$Z$Z_period)),
  log_prec_rw_period = 0,
  lag_logit_phi_period = 0,
  
  u_spatial_str = rep(0, ncol(mf$Z$Z_spatial)),
  log_prec_spatial = 0,
  
  beta_spike_2000 = 0,
  beta_spike_1999 = 0,
  beta_spike_2001 = 0,
  log_overdispersion = 0,
  
  eta1 = array(0, c(ncol(mf$Z$Z_country), ncol(mf$Z$Z_period), ncol(mf$Z$Z_age))),
  log_prec_eta1 = 0,
  lag_logit_eta1_phi_age = 0,
  lag_logit_eta1_phi_period = 0,
  #
  eta2 = array(0, c(ncol(mf$Z$Z_spatial), ncol(mf$Z$Z_period))),
  log_prec_eta2 = 0,
  lag_logit_eta2_phi_period = 0,
  #
  eta3 = array(0, c(ncol(mf$Z$Z_spatial), ncol(mf$Z$Z_age))),
  log_prec_eta3 = 0,
  lag_logit_eta3_phi_age = 0
)

tmb_int$random <- c("beta_0",
                    "u_spatial_str",
                    "u_age",
                    "u_period",
                    "beta_tips_dummy",
                    "u_tips",
                    "beta_spike_2000",
                    "beta_spike_1999",
                    "beta_spike_2001",
                    "eta1",
                    "eta2",
                    "eta3",
                    "omega1",
                    "omega2"
)

if(mf$mics_toggle) {
  tmb_int$data <- c(tmb_int$data,
                    "Z_tips_mics" = mf$Z$Z_tips_mics,
                    "R_tips_mics" = mf$R$R_tips_mics,
                    "log_offset_mics" = list(log(filter(mf$observations$full_obs, survtype == "MICS")$pys)),
                    "births_obs_mics" = list(filter(mf$observations$full_obs, survtype == "MICS")$births),
                    
                    "X_spike_2000_mics" = list(model.matrix(~0 + spike_2000, mf$observations$full_obs %>% filter(survtype == "MICS"))),
                    "X_spike_1999_mics" = list(model.matrix(~0 + spike_1999, mf$observations$full_obs %>% filter(survtype == "MICS"))),
                    "X_spike_2001_mics" = list(model.matrix(~0 + spike_2001, mf$observations$full_obs %>% filter(survtype == "MICS")))
  )
  tmb_int$par <- c(tmb_int$par,
                   "u_tips_mics" = list(rep(0, ncol(mf$Z$Z_tips_mics)))
  )
  tmb_int$random <- c(tmb_int$random, "u_tips_mics")
}

f <- parallel::mcparallel(TMB::MakeADFun(data = tmb_int$data,
                               parameters = tmb_int$par,
                               DLL = "relaxed_eta2",
                               random = tmb_int$random,
                               hessian = FALSE))
parallel::mccollect(f)

obj <-  TMB::MakeADFun(data = tmb_int$data,
                       parameters = tmb_int$par,
                       DLL = "relaxed_eta2",
                       random = tmb_int$random,
                       hessian = FALSE)

f <- stats::nlminb(obj$par, obj$fn, obj$gr)
f$par.fixed <- f$par
f$par.full <- obj$env$last.par

fit <- c(f, obj = list(obj))
# fit$sdreport <- sdreport(fit$obj, fit$par)

class(fit) <- "naomi_fit"  # this is hacky...
fit <- naomi::sample_tmb(fit, random_only=TRUE)

tmb_results <- dfertility::tmb_outputs(fit, mf, areas) 

write_csv(tmb_results, paste0(tolower(iso3), "_fr.csv"))

fr_plot <- read.csv(paste0("depends/", tolower(iso3), "_fr_plot.csv"))

fr_plot <- fr_plot %>%
  left_join(areas %>% st_drop_geometry() %>% select(area_id, area_name))

tfr_plot <- tmb_results %>%
  filter(area_level == 1, variable == "tfr") %>%
  ggplot(aes(x=period, y=median)) +
  geom_line() +
  geom_ribbon(aes(ymin=lower, ymax=upper), alpha=0.5) +
  geom_point(data = fr_plot %>% filter(variable == "tfr", value <10), aes(y=value, color=survey_id)) +
  facet_wrap(~area_name, ncol=5) +
  labs(y="TFR", x=element_blank(), color="Survey ID", title=paste(iso3, "| Provincial TFR")) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    text = element_text(size=14)
  )

district_tfr <- tmb_results %>%
  filter(area_level == 2, variable == "tfr") %>%
  ggplot(aes(x=period, y=median)) +
  geom_line() +
  geom_ribbon(aes(ymin=lower, ymax=upper), alpha=0.5) +
  facet_wrap(~area_name, ncol=8) +
  theme_minimal() +
  labs(y="TFR", x=element_blank(), title=paste(iso3, "| District TFR"))

dir.create("check")
pdf(paste0("check/", tolower(iso3), "_tfr_admin1.pdf"), h = 12, w = 20)
tfr_plot
dev.off()
pdf(paste0("check/", tolower(iso3), "_tfr_district.pdf"), h = 12, w = 20)
district_tfr
dev.off()