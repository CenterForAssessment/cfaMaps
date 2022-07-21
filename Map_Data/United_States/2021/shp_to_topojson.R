########################################################################################
###
### Script to rename and convert 2021 shape files to topoJSON
### All Shape files downloaded from
### https://nces.ed.gov/programs/edge/Geographic/DistrictBoundaries
### toposimply installed via npm i topojson-simplify
### mapshaper installed via npm i mapshaper
###
### Two types of files are produced
### 1. Individual State/Territory topoJSON files 
### 2. National file
###
########################################################################################

### Load packages 
require(sf)
require(geojsonio)
require(data.table)

### Load Data
state.lookup <- fread("Base_Files/State_Codes.csv", colClasses=rep("character", 3))

### Read, fix, and write .shp files 
US_SchoolDistrict_2021 <- read_sf("Base_Files/schooldistrict_sy2021_tl21.shp")
US_SchoolDistrict_2021 <- st_make_valid(US_SchoolDistrict_2021)
state.ids <- state.lookup[STATEFP %in% unique(US_SchoolDistrict_2021$STATEFP)] 
US_SchoolDistrict_2021 <- merge(US_SchoolDistrict_2021, state.ids)
st_write(US_SchoolDistrict_2021, "Base_Files/US_SchoolDistrict_2021.shp", append=FALSE)
save(state.ids, file="Base_Files/state.ids.Rdata")

########################################################################################
### STEP 1: Create district maps by state & internal district boundaries
########################################################################################
setwd("Base_Files")
load("state.ids.Rdata")
system("mapshaper US_SchoolDistrict_2021.shp -split STATEFP -o")

for (i in state.ids$STATEFP) {
	print(paste("Starting:", state.abbreviation <- state.ids[STATEFP==i]$STATE_ABBREVIATION))
	system(paste0("mapshaper -i ", i, ".shp -filter-fields STATE,NAME -rename-fields State=STATE,District=NAME -o ", state.abbreviation, "_1.topojson format=topojson"))
	system(paste0("toposimplify -P 0.05 -f ", state.abbreviation, "_1.topojson -o ", state.abbreviation, "_2.topojson"))
	system(paste0("mapshaper -i ", state.abbreviation, "_2.topojson -snap -clean -o ", state.abbreviation, ".topojson format=topojson"))
	file.remove(c(paste0(state.abbreviation, c("_1.topojson", "_2.topojson")), paste0(i, c(".dbf", ".prj", ".shp", ".shx"))))
	file.rename(paste0(state.abbreviation, ".topojson"), paste0("../topoJSON/", state.abbreviation, ".topojson"))
# 	if (state.abbreviation %in% c("HI", "AS", "GU", "MP", "PR", "VI", "DC")) {
# 		system(paste0("mapshaper -i ", i, ".shp -filter-fields STATE,NAME -rename-fields State=STATE,District=NAME -o ", state.abbreviation, "_3.topojson format=topojson"))
# 	} else {
# 		system(paste0("mapshaper -i ", i, ".shp -filter-fields STATE,NAME -rename-fields State=STATE,District=NAME -innerlines -o ", state.abbreviation, "_3.topojson format=topojson"))
# 	}
# 	system(paste0("toposimplify -P 0.05 -f ", state.abbreviation, "_3.topojson -o ", state.abbreviation, "_4.topojson"))
# 	system(paste0("mapshaper -i ", state.abbreviation, "_4.topojson -snap -clean -o ", state.abbreviation, "_INNERLINES.topojson format=topojson"))
# 	file.remove(c(paste0(state.abbreviation, c("_3.topojson", "_4.topojson")), list.files(pattern=paste0(i, "\\."))))
# 	file.rename(paste0(state.abbreviation, "_INNERLINES.topojson"), paste0("../topoJSON/", state.abbreviation, "_INNERLINES.topojson"))
}

###########################################
### STEP 2: Create national state map
###########################################
system("mapshaper -i cb_2018_us_state_500k.shp -filter-fields NAME -rename-fields State=NAME -o US_State_Map_1.topojson format=topojson")
system(paste0("toposimplify -P 0.05 -f US_State_Map_1.topojson -o US_State_Map.topojson"))
file.remove("US_State_Map_1.topojson")
file.rename("US_State_Map.topojson", "../topoJSON/US_State_Map.topojson")

#########################################################
### STEP 3: Create National District file (version 1)
#########################################################
system("mapshaper -i US_SchoolDistrict_2021.shp -filter-fields STATE,NAME -rename-fields State=STATE,District=NAME -o US_National_School_Districts_Map_2021_V1_1.topojson format=topojson")
system("toposimplify -P 0.025 -f US_National_School_Districts_Map_2021_V1_1.topojson -o US_National_School_Districts_Map_2021_V1_2.topojson")
system("mapshaper -i US_National_School_Districts_Map_2021_V1_2.topojson -snap -clean -o US.topojson format=topojson")
file.remove(c("US_National_School_Districts_Map_2021_V1_1.topojson", "US_National_School_Districts_Map_2021_V1_2.topojson"))
file.rename("US.topojson", "../topoJSON/US.topojson")

###############################################################################################
### STEP 4: Merge together INNERLINES and US_STATE file for National District File (version 2)
### DOESN'T SEEM TO WORK TO WELL SO COMMENTING OUT FOR NOW BUT SAVING (JUST IN CASE) FOR LATER
###############################################################################################
# setwd("../topoJSON")
# system(paste0("mapshaper -i ", paste(paste(state.ids$STATE_ABBREVIATION, "topojson", sep="_INNERLINES.", collapse=" "), "US_State_Map.topojson", collapse=" "), " combine-files -o US_National_School_Districts_Map_2021_V2_1.topojson format=topojson"))
# system(paste0("toposimplify -P 0.03 -f US_National_School_Districts_Map_2021_V2_1.topojson -o US_National_School_Districts_Map_2021_V2_2.topojson"))
# system(paste0("mapshaper -i US_National_School_Districts_Map_2021_V2_2.topojson -snap -clean -o US_National_School_Districts_Map_2021_V2.topojson"))
# file.remove(c("US_National_School_Districts_Map_2021_V2_1.topojson", "US_National_School_Districts_Map_2021_V2_2.topojson"))