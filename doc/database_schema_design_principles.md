# How to design the historical adress database ? #
For historical geocoding, we need a historical database of adresses.
Here are some thought on how we designed it.

## Context ##
Historical geodata are un-precise in several ways.
Data are temporally fuzzy, spatially fuzzy, and incomplete.
Moreover, tranckign the data source and creation is important.
The available dat ais mainly road network with road name manually entered by historians,
for a set of maps.
We have very few data available about building numbering. 
We also have data from historical sources that can prove that a given numbering in a given road existed at a given date, 
without precision about this numbering localisation.

## Requirement ##
Requirements :
 - we need a generic solution that works for the entire city of Paris (and can be extended to other french places), for adresses between 
1810 and today.
 - extensibility : it should be easy to add other data from other historical map
 - editability : the database should be relationnaly well protected to avoid data corruption
 - trackability : the data sources, and successive modification, should be stored.
 - scarcity : some input data are sparse spatially or temporally, hence the model has to allow this
 - ease of use : futur user and maintenainer of the database are not likely to be expert dba. The database is then designed toward ease of use and of understanding, sometime at the price of storage. 
 
## Overall solution ##
We center our modelling on road axis with semantic information (name).
We do not force to use topology on road axis because it is not strictly required for geocoding,
and because it greatly increases the complexity (in perticular for editing).
Buidling numbers are stored separately to raod axis, and can be linked to one or several axis.

We use the postgres inheritance mechanism to ensure felxibility and extensibility.

## Detailed solution ##

### Base infrastructure for geohistorical objects
#### historical_source ####
Before putting anything in the geohistorical database, we define the historical sources.


`historical_source` :
 - historical sources are designated by a unique `short_name`, 
 - equivalent to a more correct `full_name`.
 - Another `description` field allow to explain in detail the filiation of the data source.
 - Each source has a default fuzzy `default_fuzzy_date`. The date is expressed as a trapezoid probability function
 - Sources also have `default_spatial_precision`, which is in fact a dictionnary defining the spatial precision for the different type of objects in this source. For instance a source may contain building (precision 1 m) and road axis (precision 2 m)
 
#### type_of_origin ####
Each `geohistorical_object` in the database is in fact the result of an interpretation process of a real historical document.
It is then essential to document the way this interpretation was made, that is the origin of the informatic data to be stored in the database.
For instance, the interpretation may be the result of an automatic computing process, or may be the result of a specialised human.


`type_of_origin` : 
 - origin are designated by unique `short_name`,
 - equivalent to a more correct `full_name`.
 - another `description` field allow to explain in detail this origin.
 - a `fuzzy_date`, that *represents the date of the numerizing process*, usually not a long time ago ! 
 - origin may also be associated with `default_spatial_precision`, which is a simple value giving the default spatial precision of the interpretation process. For instance an automatic interpretation process may have an estimated precision of 10 meters, where an human would have an estimated precision of 1 meters.
 

#### Geohistorical objects ####
Geohistorical objects are the basic way of storing information about an identified geohistorical entity.
geohistorical objects have then a geometric part and an historical part.


`geohistorical_objects` : 
 - objects have an historically accurate `historical_name`,
 - and a more practical `normalised_name`
 - objects have a geometry, expressed in the correct spatial reference system
 - objects have a `historical_source`, which detail to which historical document they are associated
 - objects have a `type_of_origin` explaining the process of going from an historical document to the numeric object;
 - objects may have a custom `custom_fuzzy_date` that would override the defaut fuzzy date associated to the `historical_source`
 - objects may have a custom `custom_spatial_precision` that would override the default spatial precision associated with the `historical_source` and the `type_of_origin`.
 
#### name alias #### 

The `normalised_name` of geohistorical object is very important, as it is the main human way of identifying the object.
As such, we define a table that defines relations between two different names that are deemed related by the historian.

For instance `rue de la tour du marais` may be estimated as identical as `rue de la tour`.
Furthermore, one form may be prefered.


table `name_alias` : 
 - `historical_source` : the relation is always defined for a given historical source
 - `normalised_name_1` the first name in the relation
 - `normalised_name_2` the second name in the relation
 - the `preference_ratio` express how much the first name is to be prefered to the second one.
 For instance, a `preference_ratio` of 1 defines the two names as equivalent.
 A `preference_ratio`of 10 express the idea that the first name is 10 time more preferable than the second one.


### geohistorical objects for geocoding ###

For geocoding, we use two main types of geohistorical_objects,
and annex tables to add features

####  adress localisation  ####
The first one is `adress_localisation`.
It is the potential localisation of an adress.
For instance we may extract from an historical source the fact that a given building has the number 12B.
This is a localisation, but only potential, because without the associated road name, the adress is ambiguous.


table `adress_localisation` :
 - `localisation` a geohistorical object that may be associated with the localisation of a potential adress
 - `associated_road_name` : an adress localisation may be associated to a road name so the adress is less ambiguous.

####  named road  ####

the second is `named_road`.
It is constitued of road axis, which if course have a name (potentially aliased).


table `named_road` : 
 - the `road_axis` field is the geohistorical object representing the road axis and the road name 


