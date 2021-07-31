Tierney, M., Huster, J.
ENERGY 291 - SP21
Final Project Code

This repository is meant to be a storage and communication device for a final project made
by Jonathan Huster and Mattew Tierney for Stanford University's Energy 291: Energy Optimization course.
The project is a global electricity dispatch model modeled after 
Brinkerink et al. 2021 (link: https://doi.org/10.1016/j.esr.2020.100592). 

The folder contains the final project model and required input and output folders (discussed below).
The "data" folder has its own README file which describes its contents in relation to the project.

****************************************
Notes on running Code: "Model.jl"
****************************************


The script inputs data from the folder titled "inputs". To access the files through the script, the directory on line 20
of the Julia code will need to be updated to the location of the "inputs" and "outputs" folder on your personal drive.

The solutions are outputs to a folder titled "outputs", which will need to be added to the same directory where you place the inputs folder.
Note that an iteration of the model replaces the current files in the outputs folder if not saved elsewhere.

The file outputs two CSVs to the "outputs" folder:

"PowerProdSolutions.csv" which contains the generation by fuel type (16 types) for the 164 modelled countries across 12 months. 

"Shipments.csv" contains a list of all transmission to and from each node across 12 months. 
Note that due to the size of shipments (164*164 countries * 12 months) the sheet is best converted to a 164*164 matrix
per month for ease of readability and analysis. This was done in the provided R-code (or can be done simply with SUMIFS in excel).
Previous iterations of the model were performed on a monthly basis, allowing for export of a matrix file from Julia.

Values for carbon tax and transmission constraint are updated manually in the julia code.
These can be found on lines 60 and 55 respectively.
Note that input emissions are in kgCO2/MWh, so carbon prices in $/tonne must be divided by 1000.
These are currently set to $50/tonne, $0.02/km/MWh, and 10,000 MWh respectively for carbon price, transmission cost, and transmission capacity.
This outputs the final objective value of $692 Billion as reported for the carbon tax scenario.

***********************************************************************************************************************************************


