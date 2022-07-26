########################################################################################
###
### Script to rename and convert 2021 shape files to topoJSON
### All Shape files downloaded from
### https://nces.ed.gov/programs/edge/Geographic/DistrictBoundaries
### toposimply installed via npm i topojson-simplify
### mapshaper installed via npm i mapshaper
### UNSDLEA to state district number lookup from https://nces.ed.gov/ccd/Data/zip/ccd_lea_029_2021_w_1a_080621.zip
###
### Two types of files are produced
### 1. Individual State/Territory topoJSON files 
### 2. National file
###
########################################################################################

### Load packages 
require(sf)
require(geojsonio)
require(maptools)
require(rgdal)
require(data.table)

### Utility functions
fix1 <- function(object, params) {
  r <- params[1]; scale <- params[2]; shift <- params[3:4]
  object <- elide(object, rotate=r)
  size <- max(apply(bbox(object),1,diff))/scale
  object <- elide(object,scale=size)
  object <- elide(object,shift=shift)
  return(object)
}

fixup <- function(usa, AK_Fix, HI_Fix, PR_Fix, VI_Fix) {
  alaska <- usa[usa$ST_ABBR=="AK",]
  alaska <- fix1(alaska, AK_Fix)
  proj4string(alaska) <- proj4string(usa)

  hawaii <- usa[usa$ST_ABBR=="HI",]
  hawaii <- fix1(hawaii, HI_Fix)
  proj4string(hawaii) <- proj4string(usa)

  puerto_rico <- usa[usa$ST_ABBR=="PR",]
  puerto_rico <- fix1(puerto_rico, PR_Fix)
  proj4string(puerto_rico) <- proj4string(usa)

  virgin_islands <- usa[usa$ST_ABBR=="VI",]
  virgin_islands <- fix1(virgin_islands, VI_Fix)
  proj4string(virgin_islands) <- proj4string(usa)

  usa <- usa[!usa$ST_ABBR %in% c("AK", "HI", "PR", "VI"),]
  usa <- rbind(usa, alaska, hawaii, puerto_rico, virgin_islands)

  return(usa)
}

### Parameters
state.abbs.to.retain <- c(state.abb, "VI", "PR")

#####################################################################
### STEP 1: Load data and prepare files
#####################################################################

### Load Data
state.lookup <- fread("Base_Files/State_Codes.csv", colClasses=rep("character", 3))
district.number.lookup <- fread("Base_Files/ccd_lea_029_2021_w_1a_080621.csv")

### Clean-up district.number.lookup
district.number.lookup <- district.number.lookup[,c("ST_LEAID", "LEAID"), with=FALSE]
setnames(district.number.lookup, c("ST_LEAID", "LEAID"), c("DISNUM", "GEOID"))
district.number.lookup[,GEOID:=strtail(paste0("0", GEOID), 7)]
district.number.lookup <- district.number.lookup[!duplicated(district.number.lookup, by="GEOID")]

### Read, fix, and write .shp files
US_School_Districts_2021_v1 <- read_sf("Base_Files/schooldistrict_sy2021_tl21.shp")
US_School_Districts_2021_v2 <- st_make_valid(US_School_Districts_2021_v1)
state.ids <- state.lookup[STATEFP %in% unique(US_School_Districts_2021_v1$STATEFP)][ST_ABBR %in% state.abbs.to.retain] 
save(state.ids, file="Base_Files/state.ids.Rdata")
US_School_Districts_2021_v3 <- merge(US_School_Districts_2021_v2, state.ids)
US_School_Districts_2021_v4 <- US_School_Districts_2021_v3[!is.na(US_School_Districts_2021_v3$ST_ABBR),]
US_School_Districts_2021_NON_TRANSFORMED <- merge(US_School_Districts_2021_v4, district.number.lookup, all.x=TRUE) ### 167 District without a DISNUM
st_write(US_School_Districts_2021_NON_TRANSFORMED, "Base_Files/US_School_Districts_2021_NON_TRANSFORMED.shp", append=FALSE)


US_School_Districts_2021_v1 <- readOGR("Base_Files/US_School_Districts_2021_NON_TRANSFORMED.shp")
US_School_Districts_2021_v2 <- spTransform(US_School_Districts_2021_v1, CRS("+init=epsg:9311"))
US_School_Districts_2021_TRANSFORMED <- fixup(US_School_Districts_2021_v2, c(-35,2.0,-2600000,-2400000), c(-35,1.5,-1800000,-2300000), c(20, 0.8, 2200000, -2200000), c(20, 0.8, 2700000, -2200000))
writeOGR(US_School_Districts_2021_TRANSFORMED, "Base_Files", "US_School_Districts_2021_TRANSFORMED", driver="ESRI Shapefile")


########################################################################################
### STEP 2: Create state level district maps
########################################################################################

setwd("Base_Files")
load("state.ids.Rdata")
system("mapshaper US_School_Districts_2021_NON_TRANSFORMED.shp -split STATEFP -o")

for (i in state.ids$STATEFP) {
	print(paste("Starting:", state.abbreviation <- state.ids[STATEFP==i]$ST_ABBR))
	system(paste0("mapshaper -i ", i, ".shp -filter-fields DISNUM,NAME -rename-fields District_Number=DISNUM,District_Name=NAME -o ", state.abbreviation, "_1.topojson format=topojson"))
	system(paste0("toposimplify -P 0.05 -f ", state.abbreviation, "_1.topojson -o ", state.abbreviation, "_2.topojson"))
	system(paste0("mapshaper -i ", state.abbreviation, "_2.topojson -snap -clean -o ", state.abbreviation, ".topojson format=topojson"))
	file.remove(c(paste0(state.abbreviation, c("_1.topojson", "_2.topojson")), paste0(i, c(".dbf", ".prj", ".shp", ".shx"))))
	file.rename(paste0(state.abbreviation, ".topojson"), paste0("../topoJSON/", state.abbreviation, ".topojson"))
}

#########################################################
### STEP 3: Create National District file
#########################################################
system("mapshaper -i US_School_Districts_2021_TRANSFORMED.shp -filter-fields DISNUM,NAME -rename-fields District_Number=DISNUM,District_Name=NAME -o US_National_School_Districts_Map_2021_V1_1.topojson format=topojson")
system("toposimplify -P 0.025 -f US_National_School_Districts_Map_2021_V1_1.topojson -o US_National_School_Districts_Map_2021_V1_2.topojson")
system("mapshaper -i US_National_School_Districts_Map_2021_V1_2.topojson -snap -clean -o US.topojson format=topojson")
file.remove(c("US_National_School_Districts_Map_2021_V1_1.topojson", "US_National_School_Districts_Map_2021_V1_2.topojson"))
file.rename("US.topojson", "../topoJSON/US.topojson")