########################################################################################
###
### Script to rename and convert 2021 United States State shape files to topoJSON
### All Shape files downloaded from
### https://www.census.gov/geographies/mapping-files/time-series/geo/carto-boundary-file.html
### toposimply installed via npm i topojson-simplify
### mapshaper installed via npm i mapshaper
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

##################################################
### STEP 1: Create national state map .shp file
##################################################
US_States_v1 <- readOGR(dsn="Base_Files/cb_2018_us_state_5m.shp")
names(US_States_v1)[5:6] <- c("ST_ABBR", "STATE")
US_States_v2 <- US_States_v1[US_States_v1$ST_ABBR %in% state.abbs.to.retain,]
US_States_v3 <- spTransform(US_States_v2, CRS("+init=epsg:9311"))
US_States_FINAL <- fixup(US_States_v3, c(-35,2.0,-2600000,-2400000), c(-35,1.5,-700000,-2300000), c(20, 0.8, 2200000, -2200000), c(20, 0.8, 2700000, -2200000))
writeOGR(US_States_FINAL, "Base_Files", "US_States_FINAL", driver="ESRI Shapefile")

####################################################
### STEP 2: Convert .shp file to topojson file
####################################################
system("mapshaper -i US_States_FINAL.shp -filter-fields ST_ABBR,STATE -rename-fields State=STATE,Abbreviation=ST_ABBR -o US_State_Map_1.topojson format=topojson")
system(paste0("toposimplify -P 0.05 -f US_State_Map_1.topojson -o US_State_Map.topojson"))
file.remove("US_State_Map_1.topojson")
file.rename("US_State_Map.topojson", "../topoJSON/US_State_Map.topojson")