# This script processes the data from Brinkerink et al's compilation to 
# make the data more aggregated. 

library(dplyr)
library(tidyr)
library(ggplot2)

#Set locations and read in files
##################################################################
DIR <- file.path("C:","Users","jonat","Box Sync","classes","21_sp","291","project","Project", "CodeSubmission", "outputs")
RESULTSDIR <- file.path(DIR)
HISTORICALDIR <- file.path(DIR, "..", "data", "historical")

HISTORICALFILE <- file.path(HISTORICALDIR, "PowerProdIEA.csv")
MODELEDFILE <- file.path(RESULTSDIR, "PowerProdSolutions.csv")

historical <- read.csv(HISTORICALFILE)
modeled <- read.csv(MODELEDFILE)
##################################################################

# Analyze the results
##################################################################

modeled %>%
  group_by(iso, fuel) %>%
  summarise(mod = sum(x1)) %>%
  ungroup() ->
  annual_modeled

historical %>%
  gather(fuel, his, -c(iso,year)) %>%
  left_join(annual_modeled) %>%
  mutate(diff = mod/his) %>%
  filter(!(his==0 & mod==0)) ->
  testDB

testDB %>%
  select(-his, -mod) %>%
  spread(fuel, diff)

##################################################################

# Plot the results
##################################################################
ggplot(testDB %>% filter(diff<10)) +
  geom_point(aes(iso, diff, color = fuel, size = his)) +
  scale_color_discrete(name = "Fuel") +
  scale_size_continuous(name = "Production") +
  xlab("Country") +
  ylab("Relative Difference") +
  ggtitle("Relative Accuracy of Dispatch Model")
##################################################################