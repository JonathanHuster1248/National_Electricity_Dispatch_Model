# This script processes the data from Brinkerink et al's compilation to 
# make the data more aggregated. 

library(dplyr)
library(tidyr)
library(openxlsx)

#Set locations and read in files
##################################################################
DIR <- file.path("C:","Users","jonat","Box Sync","classes","21_sp","291","project", "Project", "CodeSubmission", "data")
RAWDATADIR <- file.path(DIR, "raw")
PROCESSEDDATADIR <- file.path(DIR, "processed")

DEMANDFILE <- file.path(RAWDATADIR, "All Demand UTC 2015.csv")
HYDROFILE  <- file.path(RAWDATADIR, "Hydro_Monthly_Profiles (2015).csv")
PLANTFILE  <- file.path(RAWDATADIR, "PLEXOS-World 2015_Gold_V1.1.xlsx")
CSPFILE    <- file.path(RAWDATADIR, "renewables.ninja.Csp.output.full.adjusted.csv")
SOLARFILE  <- file.path(RAWDATADIR, "renewables.ninja.Solar.farms.output.full.adjusted.csv")
WINDFILE   <- file.path(RAWDATADIR, "Renewables.ninja.wind.output.Full.adjusted.csv")
COUNTRYCONTINENTMAPFILE <- file.path(PROCESSEDDATADIR, "country_contient.csv")
CONTINENTMAPFILE <- file.path(PROCESSEDDATADIR, "continent_mapping.csv")

demand    <- read.csv(DEMANDFILE)
hydro     <- read.csv(HYDROFILE)
plant     <- read.xlsx(PLANTFILE, sheet = "Properties")
# csp     <- read.csv(CSPFILE) # There are only about 30 csp plants. We'll ignore them for now
solar     <- read.csv(SOLARFILE)
wind      <- read.csv(WINDFILE)
countrycontinentmap <- read.csv(COUNTRYCONTINENTMAPFILE) %>% mutate(continent = if_else(is.na(continent), "NA", continent))
continentmap <- read.csv(CONTINENTMAPFILE) %>% mutate(abbrev = if_else(is.na(abbrev), "NA", abbrev))

nonDispatchFuels <- c("Sol", "Win", "oil")
##################################################################

# Process Hydro
##################################################################
hydro %>%
  gather(month, generation, -c(NAME)) %>%
  separate(NAME, c("country", "fuel", "location"), sep = "_") %>%
  mutate(month = as.integer(gsub("M", "", month))) %>%
  group_by(month, country) %>%
  summarize(generation = sum(generation)) %>%
  ungroup() -> 
  global_monthly_hydro
  
##################################################################

# Process Plants
##################################################################

# This sheet has data on generators, batteries, and fuel prices 
# for a first pass, ignore batteries
plant %>% 
  filter(child_class == "Generator",
         property %in% c("Max Capacity", "Units"),
         !grepl("Exclude CSP|Exclude 2016-2019 Generators|Include Nuclear Constraint", scenario)) %>% #"Heat Rate", "Start Cost", 
  select(child_object, property, value) %>% 
  spread(property, value) %>%
  mutate(value = `Max Capacity`*Units) %>%
  select(child_object, value) %>%
  mutate(country = gsub("[_-]+.*", "", child_object),
         state = if_else(grepl("-", gsub("_.*", "", child_object)), gsub("[[:alpha:]]+-", "", gsub("_.*", "", child_object)), NA_character_),
         fuel = gsub("_.*", "", gsub("^[[:alpha:]-]+_", "", child_object)),
         plant = gsub("[[:alpha:]-]+_[[:alpha:]]+_", "", child_object)) %>%
  select(country, fuel, plant, value) -> 
  generator_capacity_plant
  
generator_capacity_plant %>%
  filter(!(fuel %in% nonDispatchFuels))%>%
  group_by(country, fuel) %>%
  summarise(value = sum(value)) %>%
  ungroup %>% 
  spread(fuel, value, fill = 0) %>%
  mutate(imports = 1e8) ->
  generator_capacity_country

generator_capacity_country %>%
  pull(country) %>% 
  unique() ->
  countries

fuels <- names(generator_capacity_country)[-1]

plant %>% 
  filter(child_class == "Fuel",
         property == "Price") %>%
  select(iso = child_object, value) %>%
  separate(iso, c("continent", "country_fuel"), sep = "[-_]") %>%
  mutate(country = if_else(grepl(" ", country_fuel), gsub(" .*", "", country_fuel), "default"),
         fuel = gsub(".* ", "", country_fuel)) %>%
  select(-country_fuel) ->
  holder 

continentmap %>% 
  left_join(holder %>% 
              filter(country == "default", fuel != "CHN") %>% 
              select(-country)) %>%
  select(-continent) %>%
  rbind(holder %>% 
          filter(fuel == "Oil") %>%
          group_by(continent, fuel) %>% 
          summarise(value = median(value)) %>%
          ungroup() %>%
          rename("abbrev" = "continent")) ->
  continent_default

 

countrycontinentmap %>%
  merge(tibble(fuel = fuels)) %>%
  left_join(holder %>% select(country, fuel, value), by=c("country", "fuel")) %>%
  left_join(continent_default, by = c("continent" = "abbrev", "fuel")) %>%
  mutate(value = if_else(is.na(value.x), value.y, value.x)) %>%
  select(country, fuel, value) %>%
  spread(fuel,value) %>%
  mutate(imports = 1000) ->
  fuel_price_country

##################################################################

# Process Demand
##################################################################

# Demand is currently by hour. Let's aggregate by month and gather our data
demand %>%
  tibble() %>%
  gather(iso, demand, -c(Datetime)) %>%
  separate(Datetime, c("Date", "Time"), sep = " ") %>%
  na.omit() %>%
  separate(Date, c("day", "month", "year"), sep = "/") %>%
  separate(iso, c("continent", "country", "state"), sep = "\\.") ->
  demand_long

demand_long %>%
  filter(is.na(state),
         country %in% countries) %>%
  group_by(month, country) %>%
  summarise(demand = sum(demand)) %>% 
  ungroup() %>%
  spread(month, demand) ->
  global_monthly_demand

##################################################################

# Process Solar
##################################################################
solar %>%
  separate(Datetime, c("Date", "time"), sep = " ") %>%
  na.omit() %>%
  separate(Date, c("day", "month", "year"), sep = "/") %>%
  select(-day, -time, -year) %>%
  group_by(month) %>%
  summarise_all(sum) %>%
  ungroup %>%
  gather(plant, generation, -c(month)) %>%
  mutate(country = gsub("_.*", "", plant),
         fuel = "Sol",
         plant = gsub("[[:alpha:]]+_[[:alpha:]]+_", "", plant)) %>%
  group_by(month, country) %>%
  summarize(generation = sum(generation)) %>%
  ungroup() -> 
  global_monthly_solar


##################################################################

# Process Wind
##################################################################
wind %>%
  separate(Datetime, c("Date", "time"), sep = " ") %>%
  na.omit() %>%
  separate(Date, c("day", "month", "year"), sep = "/") %>%
  select(-day, -time, -year) %>%
  group_by(month) %>%
  summarise_all(sum) %>%
  ungroup %>%
  gather(plant, generation, -c(month)) %>%
  mutate(country = gsub("_.*", "", plant),
         fuel = "Win",
         plant = gsub("[[:alpha:]]+_[[:alpha:]]+_", "", plant)) %>%
  group_by(month, country) %>%
  summarize(generation = sum(generation)) %>%
  ungroup() -> 
  global_monthly_wind


##################################################################

# Write the now processed files
##################################################################
demand     <- write.csv(global_monthly_demand, file.path(PROCESSEDDATADIR, "demand.csv"), row.names = FALSE)
hydro      <- write.csv(global_monthly_hydro, file.path(PROCESSEDDATADIR, "hydro.csv"), row.names = FALSE)
price      <- write.csv(fuel_price_country, file.path(PROCESSEDDATADIR, "price.csv"), row.names = FALSE)
generator  <- write.csv(generator_capacity_country, file.path(PROCESSEDDATADIR, "generator.csv"), row.names = FALSE)
solar      <- write.csv(global_monthly_solar, file.path(PROCESSEDDATADIR, "solar.csv"), row.names = FALSE)
wind       <- write.csv(global_monthly_wind, file.path(PROCESSEDDATADIR, "wind.csv"), row.names = FALSE)

##################################################################