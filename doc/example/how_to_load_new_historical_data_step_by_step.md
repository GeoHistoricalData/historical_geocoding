
# How to load new data for geohistorical database step by step #

## Brief ##
You should start from a working database, with geohistorical_object and historical_geocoding extensions enabled.


The workflow is simple : 
 - add your data in a new schema, 
 - add a new historical_source and numerical_origin_process in the 'geohistorical_object' schema and appropriate table
 - in your new schema, create new tables that inherits those from historical_geocoding
 - register your formated table for historical_geocoding through inheritence and registering function
 - format your data and fill your new tables

## Details##

### Add your data in a new schema###

1. create a schema :
	`CREATE SCHEMA IF NOT EXISTS verniquet_paris`
2. import your data in this schema, for instance with shp2pgsql, QGIS, etc.
	`/usr/lib/postgresql/9.5/bin/shp2pgsql -d -I /media/sf_RemiCura/DATA/Donnees_belleepoque/reseau_routier_benoit_20160701/verniquet_l93_utf8_corr.shp verniquet_paris.verniquet_src_axis  > /tmp/tmp_verniquet.sql ;
    psql -d geocodage_historique -f /tmp/tmp_verniquet.sql`
	
Now your data are in the database in a dedicated schema

### Create the appropriate entry in `historical_source` and `numerical_origin_process` ###

1. Add an entry for your new data source in `historical_source`
For instance
	
	INSERT INTO geohistorical_object.historical_source VALUES 
	('verniquet_paris' -- short unique name
	, 'plan de verniquet de la ville de paris, X edition' --long precise name
	, 'super plan, force, faiblesse, d ou viennent les scans, etc' -- general comments on this historical data source
	, sfti_makesfti(1783, 1785, 1791, 1799) -- define here the time spawn of the historical source
	,  '{"default": 2, "road_axis":2, "building":1, "number":10}'::json --define here the estimated spatial precision of this historical source
	) ; 

2. If necessary, add an entry for the editing process associated to this new data source 
	
	
	INSERT INTO geohistorical_object.numerical_origin_process VALUES
	('manual_editing_of_verniquet'
		, 'several people from geohistoricaldata project manually edited these data'
		, 'The data was edited using a scan XXX as a background, with XXX toool. Data was cross validated, checked in XXX ways, etc. '
		, sfti_makesfti(2013, 2013, 2015,2015) -- define here time of editing
		, '{"default": 1, "road_axis":3, "building":0.5, "number":1.5}'::json) --estimate here the spatial precision associated to the editing process
		
### Create new tables inheriting from `historical_geocoding` ###

You can create several tables that will add to the geocoding your data.
To this end, your table must inherit from 
