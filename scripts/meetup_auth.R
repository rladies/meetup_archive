cat("Session is non-interactive. Starting meetup authentication process.\n")

temptoken <- tempfile(fileext = ".rds")
encr_path <- "scripts/secret_encr.rds"

key <- cyphr::key_sodium(sodium::hex2bin(Sys.getenv("MEETUP_PWD")))

cyphr::decrypt_file(
  here::here(encr_path),
  key = key,
  dest = temptoken
)

token <- readRDS(temptoken)[[1]]
token <- meetupr::meetup_auth(
  token = temptoken,
  cache = FALSE
) 

cat("\t authenticating...\n\n")
k <- meetupr::meetup_auth(token = temptoken)
