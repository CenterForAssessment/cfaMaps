########################################################################################
###
### Script to rename and convert 2021 shape files to both geoJSON and topoJSON
### All Shape files downloaded from
### https://nces.ed.gov/programs/edge/Geographic/DistrictBoundaries
### toposimply installed via npm i topojson-simplify
### mapshaper installed via npm i mapshaper
###
########################################################################################

### Load packages 
require(sf)
require(geojsonio)
require(data.table)

### Directories 
current_directory <- getwd()
file_directory <- "Map_Data/United_States/Base_Files"

### Load Data
state.lookup <- fread("Base_Files/State_Codes.csv", colClasses=rep("character", 3))

### Read, fix, and write .shp files 
#district_shape_file <- read_sf("Map_Data/United_States/Base_Files/schooldistrict_sy2021_tl21.shp")
#state_shape_file <- read_sf("Map_Data/United_States/Base_Files/cb_2018_us_state_500k.shp")
#district_shape_file <- st_make_valid(district_shape_file)
#state_shape_file <- st_make_valid(state_shape_file)
#st_write(district_shape_file, "Map_Data/United_States/Base_Files/schooldistrict_sy2021_tl21_CLEANED.shp", driver="ESRI Shapefile")
#st_write(state_shape_file, "Map_Data/United_States/Base_Files/cb_2018_us_state_500k_CLEANED.shp", driver="ESRI Shapefile")

### STEP 1: Create district maps and outlines by state
### Outlines are created to create clean state boundaries in national map
setwd(file_directory)
system("mapshaper schooldistrict_sy2021_tl21_CLEANED.shp -split STATEFP -o")
state.ids <- data.table(STATEFP=state_shape_file$STATEFP, STATE_ABBREVIATION=state_shape_file$STUSPS, STATE_NAME=state_shape_file$NAME, key="STATEFP")

for (i in state.ids$STATEFP) {
	print(paste("Starting:", state.abbreviation <- state.ids[STATEFP==i]$STATE_ABBREVIATION))
	system(paste0("mapshaper -i ", i, ".shp -filter-fields STATEFP,NAME -rename-fields State=STATEFP,District=NAME -o ", state.abbreviation, "_1.topojson format=topojson"))
	system(paste0("toposimplify -P 0.05 -f ", state.abbreviation, "_1.topojson -o ", state.abbreviation, "_2.topojson"))
	system(paste0("mapshaper -i ", state.abbreviation, "_2.topojson -snap -clean -o ", state.abbreviation, ".topojson format=topojson"))
	system(paste0("mapshaper -i ", i, ".shp -dissolve -snap -clean -o ", state.abbreviation, "_1_OUTLINE.topojson format=topojson"))
	system(paste0("toposimplify -P 0.05 -f ", state.abbreviation, "_1_OUTLINE.topojson -o ", state.abbreviation, "_2_OUTLINE.topojson"))
	system(paste0("mapshaper -i ", state.abbreviation, "_2_OUTLINE.topojson -snap -clean -o ", state.abbreviation, "_OUTLINE.topojson format=topojson"))
	file.remove(c(paste0(state.abbreviation, "_1.topojson"), paste0(state.abbreviation, "_1_OUTLINE.topojson"), paste0(state.abbreviation, "_2.topojson"), paste0(state.abbreviation, "_2_OUTLINE.topojson"), list.files(pattern=paste0(i, "\\."))))
	file.rename(paste0(state.abbreviation, ".topojson"), paste0("../topoJSON/", state.abbreviation, ".topojson"))
	file.rename(paste0(state.abbreviation, "_OUTLINE.topojson"), paste0("../topoJSON/", state.abbreviation, "_OUTLINE.topojson"))
}
setwd(current_directory)

### STEP 2: Stitch together state maps to create a national map 
setwd("topoJSON")
system(paste0("mapshaper -i ", paste(state.ids$STATE_ABBREVIATION, "topojson", sep=".", collapse=" "), " ", paste(state.ids$STATE_ABBREVIATION, "topojson", sep="_OUTLINE.", collapse=" "), " combine-files -o US_National_Districts_Map_2021.topojson format=topojson"))
system("mapshaper -i US_National_Districts_Map_2021_1.topojson -snap -clean -o US_National_Districts_Map_2021.topojson")
setwd(current_directory)







### National State Map
setwd(file_directory)
system("mapshaper -i cb_2018_us_state_500k_CLEANED.shp -filter-fields NAME -rename-fields State=NAME -clean -snap -o US_National_State_Map_2021_1.topojson format=topojson")
system("toposimplify -P 0.05 -f US_National_State_Map_2021_1.topojson -o US_National_State_Map_2021.topojson")
#system("toposimplify -s 7e-7 -f US_National_State_Map_2021_1.topojson -o US_National_State_Map_2021.topojson")
file.remove("US_National_State_Map_2021_1.topojson")
file.rename("US_National_State_Map_2021.topojson", "../topoJSON/US_National_State_Map_2021.topojson")
setwd(current_directory)

### National District Map
setwd(file_directory)
system("mapshaper -i schooldistrict_sy2021_tl21_CLEANED.shp  -filter-fields NAME -rename-fields District=NAME  -clean -snap -o US_National_District_Map_2021_1.topojson format=topojson")
#system("toposimplify -s 7e-7 -f US_National_District_Map_2021_1.topojson -o US_National_District_Map_2021_2.topojson")
system("toposimplify -P 0.05 -f US_National_District_Map_2021_1.topojson -o US_National_District_Map_2021_2.topojson")
system("mapshaper -i US_National_District_Map_2021_2.topojson ../topoJSON/US_National_State_Map_2021.topojson combine-files -o US_National_District_Map_2021.topojson format=topojson")
file.remove(c("US_National_District_Map_2021_1.topojson", "US_National_District_Map_2021_2.topojson"))
file.rename("US_National_District_Map_2021.topojson", "../topoJSON/US_National_District_Map_2021.topojson")
setwd(current_directory)

### District Maps by State
system("mapshaper schooldistrict_sy2021_tl21_CLEANED.shp -split STATEFP -o")
state.ids <- data.table(STATEFP=state_shape_file$STATEFP, STATE_ABBREVIATION=state_shape_file$STUSPS, STATE_NAME=state_shape_file$NAME, key="STATEFP")

for (i in state.ids$STATEFP) {
	print(paste("Starting:", state.abbreviation <- state.ids[STATEFP==i]$STATE_ABBREVIATION))
	system(paste0("mapshaper -i ", i, ".shp -o ", state.abbreviation, "_1.topojson format=topojson -clean -snap"))
	system(paste0("mapshaper -i ", i, ".shp -dissolve -clean -snap -o ", state.abbreviation, "_1_OUTLINE.topojson format=topojson"))
	system(paste0("mapshaper -i ", i, ".shp -o ", state.abbreviation, "_1.topojson format=topojson -clean -snap"))
	system(paste0("toposimplify -P 0.05 -f ", state.abbreviation, "_1.topojson -o ", state.abbreviation, ".topojson"))
	file.remove(c(paste0(state.abbreviation, "_1.topojson"), list.files(pattern=paste0(i, "\\."))))
	file.rename(paste0(state.abbreviation, ".topojson"), paste0("../topoJSON/", state.abbreviation, ".topojson"))
}


###################################################################
###
### Create national file
###
###################################################################

system("node --max_old_space_size=8192 /usr/local/lib/node_modules/mapshaper/node_modules/topojson -s 7e-7 --q0=0 --q1=1e6 -p name=STATE_NAME -p state=STATE_FIPS -o STATE.json National_Assessment_of_Educational_Progress_20052015.shp")
system("node --max_old_space_size=8192 /usr/local/share/npm/bin/topojson -s 7e-7 --q0=0 --q1=1e6 -o STATE_NO_PROPERTIES.json National_Assessment_of_Educational_Progress_20052015.shp")
system("sed -i -e 's/National_Assessment_of_Educational_Progress_20052015/states/g' STATE.json")
system("sed -i -e 's/\\\\u0000//g' STATE.json")
system("sed -i -e 's/National_Assessment_of_Educational_Progress_20052015/states/g' STATE_NO_PROPERTIES.json")
system("sed -i -e 's/\\\\u0000//g' STATE_NO_PROPERTIES.json")
file.rename("STATE.json", "USA_States.topojson")
file.rename("STATE_NO_PROPERTIES.json", "USA_States_NO_PROPERTIES.topojson")

system("node --max_old_space_size=8192 /usr/local/share/npm/bin/topojson -s 7e-7 --q0=0 --q1=1e6 -p name=NAME -p state=STATEFP -o TEMP.json schooldistrict_sy1314_tl15.shp")
system("node --max_old_space_size=8192 /usr/local/share/npm/bin/topojson -s 7e-7 --q0=0 --q1=1e6 -o TEMP_NO_PROPERTIES.json schooldistrict_sy1314_tl15.shp")
system("sed -i -e 's/schooldistrict_sy1314_tl15/districts/g' TEMP.json")
system("sed -i -e 's/\\\\u0000//g' TEMP.json")
system("sed -i -e 's/schooldistrict_sy1314_tl15/districts/g' TEMP_NO_PROPERTIES.json")
system("sed -i -e 's/\\\\u0000//g' TEMP_NO_PROPERTIES.json")
file.rename("TEMP.json", "USA_Districts.topojson")
file.rename("TEMP_NO_PROPERTIES.json", "USA_Districts_NO_PROPERTIES.topojson")

system("mapshaper -i USA_Districts.topojson USA_States_NO_PROPERTIES.topojson combine-files -o USA_Districts_States.topojson format=topojson")
system("mapshaper -i USA_Districts_NO_PROPERTIES.topojson USA_States_NO_PROPERTIES.topojson combine-files -o USA_Districts_States_NO_PROPERTIES.topojson format=topojson")