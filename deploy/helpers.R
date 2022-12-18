# refresh_fr <- function() {
#   message("Mise a jour des données France et Regions")
#   script_fr <- "scripts/prepare_regions.R"
#   if(file.exists(script_fr)) {source(script_fr)} else {stop("Le script ", script_fr, " n'existe pas")}
#   
#   file_id <- get_file_id("tamtam", "latest.csv")
#   
#   is_refreshed <- tryCatch(FCT_prepare_regions(file_id),
#                            error = function(e) {
#                              stop("Soucis lors de la mise à jour des données France et Régions")
#                              FALSE
#                            }
#   )
# }
# 
# refresh_agglos <- function() {
#   message("Mise a jour des donnees Agglos")
#   script_Agglo <- "scripts/prepare_Agglo.R"
#   if(file.exists(script_Agglo)) {source(script_Agglo)} else {stop("Le script ", script_Agglo, " n'existe pas")}
#   is_refreshed <- tryCatch(FCT_prepare_agglo(),
#                            error = function(e) {
#                              stop("Soucis lors de la mise à jour des donnees Agglos")
#                              FALSE
#                            }
#   )
#   
#   return(is_refreshed)
# }
# 
# refresh_analyses <- function() {
#   message("Mise à jour des markdowns d'analyse")
#   script_analyses <- "scripts/prepare_analyses.R"
#   source(script_analyses)
#   is_refreshed <- tryCatch(FCT_prepare_analyses(),
#                            error = function(e) {
#                              stop("Soucis lors de la mise à jour des des markdowns d'analyse")
#                              FALSE
#                            })
#   
#   return(is_refreshed)
# }

deploy_app <- function(app_name, APP_DIR, TOKEN_RSCONNECT, launch_browser = TRUE) {
  message("Mise a jour de l'application ", app_name)
  rsconnect::setAccountInfo(name   = 'cerema-med',
                            token  = TOKEN_RSCONNECT$token,
                            secret = TOKEN_RSCONNECT$secret)
  rsconnect::deployApp(appName = app_name, appDir = APP_DIR, account="cerema-med", forceUpdate = T, launch.browser = launch_browser)
}