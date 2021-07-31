Energy 291 Final Project
Matt Tierney, Jon Huster
Data directory's README

The data subfolder contains the raw data, processed data, and processing scripts necessary to develop the CSVs
run in the main model. the raw data come from Brinkerink et al.'s data repository (https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/CBYXBY).
These data are the inputs used in Brinkerink et al.'s hourly resolved global electricity dispatch model.
The dataProcessing.R script takes these raw input files and cleans, aggregates, and reshapes the data
to suit the input format for the Julia model. The outputs of the dataProcessing.R are placed into the "processed"
output directory, which can then be moved into the inputs folder. 

The historical data has the representative data from 5 large countries. The data was gathered from the IEA
(https://www.iea.org/fuels-and-technologies/electricity). 

Because the raw data is too large (hundreds of MB per file) they have been omited for this repository.
Raw data sources can be found in the data repository distributed by Brinkerink et al. 