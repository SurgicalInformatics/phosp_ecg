# PHOSP-Covid REDCap database analysis: ECG pull
# API pull ECG images from Leicester Oxford REDCap server
# Centre for Medical Informatics, Usher Institute, University of Edinburgh 2021

# To use this, set your REDCap API token as an environment variable.
## Uncomment and run the following line:
# usethis::edit_r_environ()
## this opens up .Renviron, add your token, e.g. ccp_token = 2F3xxxxxxxxxxxxE0111
## Restart R

# 1. Meta-data pull for info
# 2. Record IDs with images.
# 3. Pull and rename images


library(RCurl)
library(REDCapR)
library(tidyverse)

# 1. Meta-data pull for info --------------------------------------------
uri = "https://data.phosp.org/api/"

project_meta_data = redcap_metadata_read(
  uri,
  Sys.getenv("phosp_token")
)


# 2. Record IDs with images. -------------------------------------------
## Functions for safe api pull
rate = rate_backoff(pause_cap = 60*5, max_times = 10)
insistent_postForm = purrr::insistently(postForm, rate)

# Get subjid
ecg_upload_data = insistent_postForm(
  uri='https://data.phosp.org/api/',
  token = Sys.getenv("phosp_token"),
  content='record',
  'fields[0]'='study_id',
  'fields[1]'='ecg_upload',
  format='csv',
  type='flat',
  rawOrLabel='raw',
  rawOrLabelHeaders='raw',
  exportCheckboxLabel='false',
  exportSurveyFields='false',
  exportDataAccessGroups='false',
  returnFormat='json'
) %>% 
  read_csv() %>% 
  drop_na(ecg_upload)

ecg_upload_study_id = ecg_upload_data %>%  
  distinct(study_id) %>% 
  pull(study_id)

# 3. Pull and rename images -------------------------------------------
record_list = ecg_upload_study_id
field_list = c("ecg_upload")
event_list = c("3_months_1st_resea_arm_1", "12_months_2nd_rese_arm_1")
directory = "ecg_raw"

for(record in record_list){
  for(field in field_list){
    for(event in event_list){
      result = 
        tryCatch({
          redcap_download_file_oneshot(
            record        = record,
            field         = field,
            redcap_uri    = uri,
            token         = Sys.getenv("phosp_token"),
            event         = event,
            overwrite     = TRUE,
            directory     = directory
          )
        }, error=function(e){})
    }
  }
}

# Rename files with study_id --------------------------------------------------
ecg_upload_data = ecg_upload_data %>% 
  mutate(
    event = stringr::str_extract(redcap_event_name, "[123]+_months"),
    filetype = stringr::str_extract(ecg_upload, "\\.[:alpha:]+$"), # Not currently used
    filename = paste0(study_id, 
                      "_",
                      event, 
                      "_",
                      ecg_upload)
  )

file.copy(
  from = paste0(directory, "/", ecg_upload_data$ecg_upload), 
  to = paste0("ecg_named", "/", ecg_upload_data$filename)
)

# Zip ------------------------------------------------------------------------
files2zip <- dir('ecg_named', full.names = TRUE)
zip(zipfile = 'ecg_named', files = files2zip)

# files2zip <- dir('ecg_raw', full.names = TRUE)
# zip(zipfile = 'ecg_raw', files = files2zip)

# Getting big now, so delete un-needed folder. 