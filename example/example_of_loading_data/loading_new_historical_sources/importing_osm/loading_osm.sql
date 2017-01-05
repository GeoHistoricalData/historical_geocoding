--------------------------------
-- Rémi Cura, 2017
-- projet geohistorical data
-- 
--------------------------------
-- import and normalise of current data
-- Import OSM house number & osm road way
--------------------------------

CREATE SCHEMA IF NOT EXISTS osm_paris;
	SET search_path to osm_paris, historical_geocoding, geohistorical_object, public; 


-- /usr/lib/postgresql/9.5/bin/shp2pgsql -c -W "LATIN1" -I ./OSM_point_adresse_paris_prepare.shp  osm_paris.osm_adress_points| psql -d geocodage_historique;
	ALTER TABLE osm_adress_points ALTER COLUMN geom TYPE geometry(point,2154) USING ST_SetSRID(geom,2154)  ; 

-- /usr/lib/postgresql/9.5/bin/shp2pgsql -c -W "LATIN1" -I ./OSM_road_axis.shp  osm_paris.osm_road_axis| psql -d geocodage_historique;
	ALTER TABLE osm_road_axis ALTER COLUMN geom TYPE geometry(multilinestring,2154) USING ST_SetSRID(geom,2154)  ; 

SELECT *
FROM osm_adress_points 
LIMIT 100 ; 

SELECT *
FROM osm_road_axis
LIMIT 100 ; 
 
 INSERT INTO  geohistorical_object.historical_source  VALUES
		('osm_paris'
			, 'Point adresse et axes des routes extraits des données OSM fin 2016 via nominatim'
			, 'Après une installation de Nominatim fin 2016, les points adresse et les axes des routes sont reconstitués en travaillant sur les données brutes. 
			De nombreuses données OSM possèdent des erreurs dans leurs tags, ou des imprécisions.'
		, sfti_makesfti(2006,2007, 2016,2016)
		,  '{"default": 10, "road_axis":5, "number":10}'::json 
		) ; 

INSERT INTO geohistorical_object.numerical_origin_process VALUES
	('osm_paris_axis'
		, 'Axes des routes issus d Open street map fin 2016, et traité/filtré pour ne garder que les bons candidats depuisi un export Nominatim'
		, 'Le nom de la ville est retrouvé par croisement avec les limites des communes de l IGN (geofla).
		note : les tags orinigaux sont gardés'
		, sfti_makesfti(2010, 2010, 2016, 2016)  -- date of data creation
		, '{"default": 5, "road_axis":5}'::json  ) 
	,
	('osm_paris_number'
		, 'Les point adresses extrais d Open Street Map après un traitement de filtrage et de consolidation depuis un export Nominatim de fin 2016.'
		, 'Le nom de la ville est retrouvé par croisement avec les limites des communes de l IGN (geofla).'
		, sfti_makesfti(2010, 2010, 2016, 2016)  -- date of data creation
		, '{"default": 10,   "number":10}'::json) --precision
		 ; 


DROP TABLE IF EXISTS osm_paris_number CASCADE; 
	CREATE TABLE osm_paris_number(
		gid serial  REFERENCES osm_adress_points(gid)
		, id_osm bigint  
		, house_number text
		, street text
		, city text
		,full_tags json 
	) INHERITS (precise_localisation) ;  
	TRUNCATE osm_paris_number CASCADE ; 


	SELECT * 
FROM osm_adress_points 
LIMIT 100 ; 


 DROP TABLE IF EXISTS osm_paris_axis CASCADE; 
	CREATE TABLE osm_paris_axis(
		gid serial  REFERENCES osm_road_axis(gid)
		, osm_id bigint  
		, osm_class  text
		, osm_type text 
		,admin_level int
		, road_name text
		, city text
	) INHERITS (rough_localisation) ;  
	TRUNCATE osm_paris_axis CASCADE ; 

SELECT *
FROM osm_road_axis
LIMIT 100 ; 
SELECT *
FROM osm_paris_axis
LIMIT 100 ; 


 
 
 
INSERT INTO osm_paris_number ( historical_name, normalised_name, geom, historical_source, numerical_origin_process, gid, id_osm, house_number, street, city, full_tags)
	SELECT house_numb ||' '||street  , house_numb ||' '||street||', '||city, geom
		,'osm_paris', 'osm_paris_number'
		, gid, id_h, house_numb, street, city
		, CASE WHEN char_length(full_tags)<250 THEN  to_json(full_tags::text[]) ELSE NULL END --NB : the export to shapefile has truncated the array, a shame ! 
	FROM osm_adress_points ; 

	SELECT *
	FROM osm_paris_number
	LIMIT 100 ; 


 
 
INSERT INTO osm_paris_axis ( historical_name, normalised_name, geom, historical_source, numerical_origin_process, gid   , osm_id  , osm_class  , osm_type  ,admin_level , road_name  , city)
	SELECT  road_name   , 
		road_name  ||', '||city,
		geom
		,'osm_paris', 'osm_paris_axis'
		, gid, osm_id, class, type, admin_leve, road_name, city 
	FROM osm_road_axis ; 

	SELECT *
	FROM osm_paris_axis
	LIMIT 100 ; 


	SELECT geohistorical_object.register_geohistorical_object_table(  'osm_paris', 'osm_paris_axis'::text)	  
		, geohistorical_object.register_geohistorical_object_table(  'osm_paris', 'osm_paris_number'::text)  ;


	SELECT historical_source ,  numerical_origin_process, count(*) as c 
	FROM historical_geocoding.rough_localisation
	GROUP BY  historical_source ,  numerical_origin_process
	ORDER BY c DESC ;

	SELECT historical_source ,  numerical_origin_process, count(*) as c 
	FROM historical_geocoding.precise_localisation
	GROUP BY  historical_source ,  numerical_origin_process
	ORDER BY c DESC ;
