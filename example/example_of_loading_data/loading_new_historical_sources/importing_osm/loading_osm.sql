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

-- tables have to be dumped/imported in order to preserve tags that may not fit in shapefile 255 char limit

--/usr/lib/postgresql/9.5/bin/pg_dump --host localhost --port 5434 --username "postgres" --no-password  --format custom --encoding UTF8 --no-privileges --no-tablespaces --verbose --no-unlogged-table-data --file "/media/sf_RemiCura/DATA/Donnees_OSM/dump_axis_number/dump_points_3.backup" --table "public.adresse_point" --table "public.road_axis" "nominatim"
--pg_restore dump_OSM_base_3.backup -d test -O -x -h localhost -p 5433

--changing tables schema and name
	ALTER TABLE public.adresse_point RENAME TO osm_adress_points ;
	ALTER TABLE public.osm_adress_points SET SCHEMA osm_paris;

	ALTER TABLE public.road_axis RENAME TO osm_road_axis ;
	ALTER TABLE public.osm_road_axis SET SCHEMA osm_paris;


	ALTER TABLE osm_adress_points ALTER COLUMN geom TYPE geometry(point,2154) USING ST_SetSRID(geom,2154)  ; 
	ALTER TABLE osm_road_axis ALTER COLUMN geom TYPE geometry(multilinestring,2154) USING ST_SetSRID(geom,2154)  ; 

	ALTER TABLE osm_road_axis DROP CONSTRAINT road_axis_pkey ; 
	ALTER TABLE osm_road_axis DROP COLUMN gid ; 
	ALTER TABLE osm_road_axis ADD PRIMARY KEY (osm_id) ; 

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
		, 'Axes des routes issus d Open street map fin 2016, et traité/filtré pour ne garder que les bons candidats depuis un export Nominatim'
		, 'Le nom de la ville est retrouvé par croisement avec les limites des communes de l IGN (geofla).
		note : les tags orinigaux sont gardés quand ils ne sont pas trop longs (limitation du shapefile)'
		, sfti_makesfti(2010, 2010, 2016, 2016)  -- date of data creation
		, '{"default": 5, "road_axis":5}'::json  ) 
	,
	('osm_paris_number'
		, 'Les point adresses extrais d Open Street Map après un traitement de filtrage et de consolidation depuis un export Nominatim de fin 2016.'
		, 'Le nom de la ville est retrouvé par croisement avec les limites des communes de l IGN (geofla).
		note : les tags orinigaux sont gardés quand ils ne sont pas trop longs (limitation du shapefile)'
		, sfti_makesfti(2010, 2010, 2016, 2016)  -- date of data creation
		, '{"default": 10,   "number":10}'::json) --precision
		 ; 


DROP TABLE IF EXISTS osm_paris_number CASCADE; 
	CREATE TABLE osm_paris_number( 
		 id_osm BIGINT   REFERENCES osm_adress_points(id_h)
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
		  id_osm BIGINT  REFERENCES osm_road_axis(osm_id)
		, osm_class  text
		, osm_type text 
		,admin_level int
		, road_name text
		, city text
		,full_tags json 
	) INHERITS (rough_localisation) ;  
	TRUNCATE osm_paris_axis CASCADE ; 

SELECT * , (name::jsonb ||extratags::jsonb)::json
FROM osm_road_axis
LIMIT 100 ; 
SELECT *
FROM osm_paris_axis
LIMIT 100 ; 


 
 
 
INSERT INTO osm_paris_number ( historical_name, normalised_name, geom, historical_source, numerical_origin_process, associated_normalised_rough_name,  id_osm, house_number, street, city, full_tags)
	SELECT house_number ||' '||street  , house_number ||' '||street||', '||city, geom
		,'osm_paris', 'osm_paris_number'
		, street||', '||city
		,   id_h
		, house_number, street, city
		,    to_json(full_tags::text[]) 
	FROM osm_adress_points ; 

	SELECT *
	FROM osm_paris_number
	LIMIT 100 ; 


 
 
INSERT INTO osm_paris_axis ( historical_name, normalised_name, geom, historical_source, numerical_origin_process, id_osm  , osm_class  , osm_type  ,admin_level , road_name  , city, full_tags)
	SELECT  road_name   , 
		road_name  ||', '||city,
		geom
		,'osm_paris', 'osm_paris_axis'
		, osm_id, class, type, admin_level, road_name, city 
		, (name::jsonb ||extratags::jsonb)::json
	FROM osm_road_axis ; 

	SELECT *
	FROM osm_paris_axis
	LIMIT 100 ; 


	SELECT geohistorical_object.register_geohistorical_object_table(  'osm_paris', 'osm_paris_axis'::text)	  
		, geohistorical_object.register_geohistorical_object_table(  'osm_paris', 'osm_paris_number'::text)  ;


	(SELECT 'rough', historical_source ,  numerical_origin_process, count(*) as c 
	FROM historical_geocoding.rough_localisation
	GROUP BY  historical_source ,  numerical_origin_process
	ORDER BY c DESC  )
	UNION ALL
	(SELECT 'precise', historical_source ,  numerical_origin_process, count(*) as c 
	FROM historical_geocoding.precise_localisation
	GROUP BY  historical_source ,  numerical_origin_process
	ORDER BY c DESC) ;
