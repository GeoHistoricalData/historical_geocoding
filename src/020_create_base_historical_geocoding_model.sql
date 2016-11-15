------------------------
-- Remi Cura, 2016 , Projet Belle Epoque
------------------------

-- this extension creates structure for historical_geocoding
-- the structure relies on 2 tables  :
  -- one table which contains a rough localisation for an adress, for instance a road axis witha  road name
  -- one table which contains a precise localisation for an adress, and that can be associated to a rough localisation

CREATE SCHEMA IF NOT EXISTS historical_geocoding ; 
-- SET search_path to historical_geocoding, geohistorical_object, public; 

-- CREATE EXTENSION IF NOT EXISTS pgsfti ; 
-- CREATE EXTENSION IF NOT EXISTS geohistorical_object ; 

-- LEAVE THIS TABLE EMPTY, INHERIT FROM IT OT USE IT, then create foreign key with function 
	-- geohistorical_object.enable_disable_geohistorical_object( schema_name, table_name,true);
	DROP TABLE IF EXISTS historical_geocoding.rough_localisation ; 
	CREATE TABLE IF NOT EXISTS historical_geocoding.rough_localisation (
	 check (false) NO INHERIT -- ensure that no data is going to be inserted in this table, it's only a template !!
	) INHERITS (geohistorical_object.geohistorical_object ); 

	-- registering the foreign keys :
	SELECT geohistorical_object.register_geohistorical_object_table( 'historical_geocoding', 'rough_localisation'::text); 
	/*
	-- example of index, not necessary here because this table will remain empty
		--geometric index
			CREATE INDEX ON historical_geocoding.rough_localisation USING GIST(geom) ; 
		--semantic index
			CREATE INDEX ON historical_geocoding.rough_localisation USING  GIN (normalised_name gin_trgm_ops);
		-- temporal index
			CREATE INDEX ON historical_geocoding.rough_localisation USING GIST(CAST(specific_fuzzy_date AS geometry)) ; 
		--index on source and origin
			CREATE INDEX ON historical_geocoding.rough_localisation (historical_source) ; 
			CREATE INDEX ON historical_geocoding.rough_localisation (numerical_origin_process) ; 
	*/
 
-- LEAVE THIS TABLE EMPTY, INHERIT FROM IT OT USE IT, then create foreign key with function 
	DROP TABLE IF EXISTS historical_geocoding.precise_localisation ; 
	CREATE TABLE IF NOT EXISTS historical_geocoding.precise_localisation (
	associated_normalised_rough_name text -- this name is an association to rough_localisation objects.
	, check (false) NO INHERIT -- ensure that no data is going to be inserted in this table, it's only a template !!
	) INHERITS (geohistorical_object.geohistorical_object );  
	
	SELECT geohistorical_object.register_geohistorical_object_table( 'historical_geocoding', 'precise_localisation') ; 
	 
-- @TODO  : this indexes should be deleted/created automatically in the enable_disable_geohistorical_object function (which shall be renommed)!




