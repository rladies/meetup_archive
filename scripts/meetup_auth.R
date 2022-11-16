cat("Session is non-interactive. Starting meetup authentication process.\n")
library(cyphr)
library(sodium)
library(meetupr)
library(here)

temptoken <- tempfile(fileext = ".rds")
encr_path <- "scripts/secret_encr.rds"

key <- key_sodium(hex2bin(Sys.getenv("MEETUPR_PWD")))

decrypt_file(
  here(encr_path),
  key = key,
  dest = temptoken
)

token <- readRDS(temptoken)[[1]]
token <- meetup_auth(
  token = temptoken,
  cache = FALSE
) 

cat("\t authenticating...\n\n")
k <- meetup_auth(token = temptoken)
