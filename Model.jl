#= Matt Tierney, Jon Huster - Energy Resource Engineering - Stanford University
Energy 291 - Optimization, S2021, Project Code, Global Electricity Dispatch Model
Revision 5: June 4th, 2021
=#

import Pkg;
Pkg.add("CSV");
Pkg.add("DataFrames")
Pkg.add("JuMP");
Pkg.add("Cbc");

using CSV
using DataFrames
using JuMP
using Cbc

######################################################################################
# Loads in CSV files as dataframes. Will need to update the URL with your own locations.
DIR = "C:\\Users\\Matt Tierney\\Documents\\ENERGY 291 - Optimization\\Test";
INPUTDIR =  DIR*"\\inputs\\";
OUTPUTDIR = DIR*"\\outputs\\";
######################################################################################

dsolar  = CSV.read(INPUTDIR*"solarrev3.csv",  DataFrame);
dwind   = CSV.read(INPUTDIR*"windrev3.csv",   DataFrame);
dhydro  = CSV.read(INPUTDIR*"hydrorev3.csv",  DataFrame);
ddemand = CSV.read(INPUTDIR*"demandrev3.csv", DataFrame);
dgen    = CSV.read(INPUTDIR*"genrev4.csv",    DataFrame);
dpriemi = CSV.read(INPUTDIR*"PriEmi.csv",     DataFrame);
ddist   = CSV.read(INPUTDIR*"distances.csv",  DataFrame);
dtrans  = CSV.read(INPUTDIR*"transmissionlines.csv",  DataFrame);

# Checks for the number of generation options in CSV and the number of time steps (periods)
fuels    = names(dgen)[2:end]
nFuels   = size(fuels)[1]
nPeriods = size(dsolar)[2]-1

# Grabs all of the country names. Which isn't actually used yet. And the number of countries. 
Countries = dsolar[:,1]
nCountries = length(Countries)

# Convert the DataFrames to matrices for each variable
Solar      = convert(Matrix,  dsolar[:,2:end])
Wind       = convert(Matrix,   dwind[:,2:end])
Hydro      = convert(Matrix,  dhydro[:,2:end])
Demand     = convert(Matrix, ddemand[:,2:end])
Generators = convert(Matrix,    dgen[:,2:end])
Prices     = convert(Vector, dpriemi[1,2:end])
Emissions  = convert(Vector, dpriemi[2,2:end])
Distances  = convert(Matrix,   ddist[:,1:end])
Translines = convert(Matrix,  dtrans[:,1:end])

# Transmission Costs and Maximum Capacity
transCost = 0.02 #[$/MW-km]
transMax = 10000 #[MW]

# Carbon Tax 
# Carbon senstitivity was run at 50/1000 ($/kg CO2)
CarbonPrice = 50/1000;

# Calculate net demand as total demand minus known renewable generation
NetDemand = Demand - Solar - Wind - Hydro;

# Generation is listed in terms of MW. So must convert this to MWh across the given time interval
maxCapacity = Generators * 24 * 365/nPeriods;


###################################
## Optimization Problem Begins ##
##################################

# Initialize model
m = Model(Cbc.Optimizer);

######## Decision variables ########
@variable(m, PowerProd[1:nCountries , 1:nFuels, 1:nPeriods] >=0);
@variable(m, translines[1:nCountries,1:nCountries] >=0);
@variable(m, ship[1:nCountries,1:nCountries, 1:nPeriods] >= 0);

####### Objective Function #########

# Single objective for minimizing cost. This will be expanded on later for emissions as well.
@objective(m, Min, sum(PowerProd[i,j,k]*Prices[j] for i=1:nCountries, j=1:nFuels, k=1:nPeriods)+
sum(PowerProd[i,j,k]*Emissions[j]*CarbonPrice for i=1:nCountries, j=1:nFuels, k=1:nPeriods)+
sum(ship[q,p,k]*Distances[q,p]*transCost for q=1:nCountries, p=1:nCountries, k=1:nPeriods));

############# Constraints ###########

# Constrains all Generators so they can't exceed capacity available
for q = 1:nFuels
    for k = 1:nPeriods
        @constraint(m, [p=1:nCountries], PowerProd[p,q,k] <= maxCapacity[p,q]);
    end
end

# Energy Balance at each node. Note that this currently only solves the first time period, but the entire optimization can be looped to solve all.
for k = 1:nCountries
    for r = 1:nPeriods
        @constraint(m, sum(Translines[p,k]*ship[p,k,r] for p=1:nCountries)-sum(Translines[k,p]*ship[k,p,r] for p=1:nCountries)
        >= NetDemand[k,r]-sum(PowerProd[k,l,r] for l=1:nFuels));
    end
end

# Transmission Constraint
for z = 1:nCountries
    for w = 1:nCountries
        @constraint(m, [r=1:nPeriods], ship[z,w,r] <= transMax);
    end
end

# Solve the model
optimize!(m)

# Print more detailed results to screen
ObjValue = objective_value(m)
CountryProduction = value.(PowerProd)
Transmission = value.(translines)
shipments = value.(ship)

dship = DataFrame(reshape(shipments,(:,1)))
dship[!, "from"] = repeat(Countries, outer=nCountries*nPeriods)
dship[!, "to"] = repeat(repeat(Countries, inner=nCountries), outer=nPeriods)
dship[!, "period"] = repeat(1:nPeriods, inner=nCountries*nCountries)
CSV.write(OUTPUTDIR*"Shipments.csv",dship)

dpower = DataFrame(reshape(CountryProduction,(:,1)))
dpower[!, "iso"] = repeat(Countries, outer=nFuels*nPeriods)
dpower[!, "fuel"] = repeat(repeat(fuels, inner=nCountries), outer=nPeriods)
dpower[!, "period"] = repeat(1:nPeriods, inner=nCountries*nFuels)

CSV.write(OUTPUTDIR*"PowerProdSolutions.csv",dpower)