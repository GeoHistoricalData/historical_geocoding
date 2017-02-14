---- Remi Cura, IGN, Copyright 2017
--

CREATE SCHEMA IF NOT EXISTS geocoding_edit; 
-- example of creating a result table for edit with geoserver and leaflet via WFS-T

-- creating an example table
DROP TABLE IF EXISTS geocoding_edit.geocoding_results CASCADE;
CREATE TABLE IF NOT EXISTS geocoding_edit.geocoding_results 
(
  gid serial primary key,
  input_adresse_query text, 
  rank integer NOT NULL,
  historical_name text,
  normalised_name text,
  fuzzy_date daterange,
  geom geometry(point,4326), 
  historical_source text,
  numerical_origin_process text,
  semantic_distance double precision,
  temporal_distance double precision,
  number_distance double precision,
  scale_distance double precision,
  spatial_distance double precision,
  aggregated_distance double precision,
  spatial_precision double precision,
  confidence_in_result double precision,
  ruid text
)
WITH (
  OIDS=FALSE
);

TRUNCATE geocoding_edit.geocoding_results ; 
INSERT INTO geocoding_edit.geocoding_results
SELECT row_number() over() as gid, '12 rue temple, paris; 1872',rank, historical_name, normalised_name
	, sfti2daterange(COALESCE(f.specific_fuzzy_date,hs.default_fuzzy_date)) AS fuzzy_date--fuzzy date
	, ST_Centroid(ST_Transform(ST_GeometryN(St_CollectionExtract(geom,1),1),4326))::geometry(point,4326) AS geom
	, historical_source, numerical_origin_process
	,semantic_distance,  temporal_distance, number_distance, scale_distance,spatial_distance
	, aggregated_distance, spatial_precision, confidence_in_result
	, CASE WHEN rank %2= 0 THEN ruid1::text ELSE ruid2 END AS ruid 
FROM historical_geocoding.geocode_name_foolproof(
	query_adress:='12 rue temple, paris'
	, query_date:= sfti_makesfti('1872-11-15'::date) -- sfti_makesftix(1872,1873,1880,1881)  -- sfti_makesfti('1972-11-15');
	, use_precise_localisation := true 
	, ordering_priority_function := '100*(semantic_distance) + 0.1 * temporal_distance + 1* number_distance + 0.1 *spatial_precision + 0.001 * scale_distance +  0.0001 * spatial_distance'
	, max_number_of_candidates := 100
	, max_semantic_distance := 0.3
		, temporal_distance_range := sfti_makesfti(1820,1820,2100,2100) 
		, optional_scale_range := numrange(0,100)
		, optional_reference_geometry := NULL -- ST_Buffer(ST_GeomFromText('POINT(652208.7 6861682.4)',2154),5)
		, optional_max_spatial_distance := 10000
	) AS  f
	LEFT OUTER JOIN geohistorical_object.historical_source AS hs ON (hs.short_name = f.historical_source)
	, geocoding_edit.make_ruid()as ruid1, geocoding_edit.make_ruid()as ruid2 ; 
 


-- TRUNCATE geocoding_edit.geocoding_results ;
SELECT *
FROM geocoding_edit.geocoding_results ;
 



-- creating a view, necessary as a wrapper for trigger, allow to avoid having trigger directly on the base table, and ths separate edit coming from user and edit coming from refresh
TRUNCATE geocoding_edit.geocoding_results_v ; 
DROP VIEW IF EXISTS geocoding_edit.geocoding_results_v ;  
CREATE VIEW geocoding_edit.geocoding_results_v AS 
SELECT gid AS gidg, gid, 
	input_adresse_query
	, rank, historical_name, normalised_name
	, fuzzy_date::text
	, geom
	, historical_source, numerical_origin_process
	,semantic_distance,  temporal_distance, number_distance, scale_distance,spatial_distance
	, aggregated_distance, spatial_precision, confidence_in_result 
	,  substring(ruid,1,12) as ruid
FROM geocoding_edit.geocoding_results ;  
--ALTER TABLE geocoding_edit.geocoding_results_v ADD PRIMARY KEY (gid) ;  

SELECT *
FROM geocoding_edit.geocoding_results_v  ; 

-- creating a function to generate unique random id
DROP FUNCTION IF EXISTS geocoding_edit.make_ruid(potential_ruid text , out ruid text)   ; 
CREATE OR REPLACE  FUNCTION geocoding_edit.make_ruid(potential_ruid text DEFAULT NULL, OUT ruid text )AS $$ -- found on internet
BEGIN
	SELECT CASE WHEN length(cleaned_ruid)=32 AND length(potential_ruid) = 32 THEN cleaned_ruid 
		ELSE md5(''||timeofday()::text||(random()*10000)::int::text) END INTO ruid
	FROM regexp_replace(potential_ruid, '[^[:alnum:]]','', 'g') AS cleaned_ruid ; 
	RETURN ;
END;
$$ LANGUAGE PLPGSQL VOLATILE CALLED ON NULL INPUT;
/*
	SELECT s, geocoding_edit.make_ruid('a52fe993a7 cde3d9149282')
	FROM generate_series(1,10) AS s  ;
*/

SELECT length(potential_ruid)=32 , 
FROM CAST('f1c90ab034e519865613a33bf6135d8f' As text) AS potential_ruid ;


--------------
-- adding a table to store final addition to geocoding
	-- adding a new numerical origin process : the user edit via the internet appli
INSERT INTO geohistorical_object.numerical_origin_process VALUES (
      'website_interactive_edit_v1',
      'Using a custom leaflet application in browser, user edit the historical name, normalized name and or geometry of the adress',
      'See web site https://www.geohistoricaldata.org/interactive_geocoding/Leaflet-WFST/examples/geocoding.html# and github https://github.com/GeoHistoricalData/historical_geocoding',
      sfti_makesfti(2017,2018,2018,2019), 
      '{"default": 0.1, "building_number":0.1}' );

DROP TABLE IF EXISTS geocoding_edit.user_edit_added_to_geocoding; 
CREATE TABLE geocoding_edit.user_edit_added_to_geocoding( 
		gid serial primary key REFERENCES geocoding_edit.geocoding_results (gid)
		, ruid text
		, input_adresse_query text
	) INHERITS (historical_geocoding.precise_localisation) ; 
SELECT geohistorical_object.register_geohistorical_object_table( 'geocoding_edit', 'user_edit_added_to_geocoding'::text) ;

CREATE INDEX ON geocoding_edit.user_edit_added_to_geocoding (ruid) ; 

SELECT *
FROM geocoding_edit.user_edit_added_to_geocoding ; 


-----------
-- adding a trigger to sync geocoding_results to geocoding_results_v

/*
DROP FUNCTION IF EXISTS geocoding_edit.geocoding_results_sync() CASCADE;
CREATE OR REPLACE FUNCTION geocoding_edit.geocoding_results_sync() RETURNS trigger AS 
$$
    BEGIN
	-- only workingon update. No inserting allowed, no deleting allowed
	IF TG_OP = 'UPDATE' THEN 
	 
		UPDATE  geocoding_edit.geocoding_results_v AS gr SET (gid, rank, historical_name, normalised_name
		,   geom
		, historical_source, numerical_origin_process
		,semantic_distance,  temporal_distance, number_distance, scale_distance,spatial_distance
		, aggregated_distance, spatial_precision, confidence_in_result, ruid) = (NEW.gid, NEW.rank, NEW.historical_name, NEW.normalised_name
		,   NEW.geom
		, NEW.historical_source, NEW.numerical_origin_process
		,NEW.semantic_distance,  NEW.temporal_distance, NEW.number_distance, NEW.scale_distance,NEW.spatial_distance
		, NEW.aggregated_distance, NEW.spatial_precision, NEW.confidence_in_result, substring(NEW.ruid,1,12)  ) 
		WHERE gr.gid = NEW.gid
			AND gr.ruid = substring(NEW.ruid,1,12) ;   
		RETURN NEW;
        END IF ; 
        IF TG_OP = 'INSERT' THEN 
		INSERT INTO geocoding_edit.geocoding_results_v SELECT NEW.gid, NEW.rank, NEW.historical_name, NEW.normalised_name
		,   NEW.geom
		, NEW.historical_source, NEW.numerical_origin_process
		,NEW.semantic_distance,  NEW.temporal_distance, NEW.number_distance, NEW.scale_distance,NEW.spatial_distance
		, NEW.aggregated_distance, NEW.spatial_precision, NEW.confidence_in_result, substring(NEW.ruid,1,12);
		RETURN NEW; 
	END IF ;
	IF TG_OP = 'DELETE' THEN 
		DELETE FROM geocoding_edit.geocoding_results_v WHERE gid = NEW.gid ;
		RETURN NEW;  
        END IF ;
        RETURN OLD ; 
    END;
$$ LANGUAGE plpgsql VOLATILE;

DROP TRIGGER geocoding_results_sync ON geocoding_edit.geocoding_results ; 
CREATE TRIGGER geocoding_results_sync AFTER UPDATE OR INSERT OR DELETE ON geocoding_edit.geocoding_results
    FOR EACH ROW EXECUTE PROCEDURE geocoding_edit.geocoding_results_sync();
*/
-----------
-- adding a trigger on geocoding_edit.geocoding_results_v : when updating, update geocoding_edit.geocoding_results only if the ruid matches !

DROP FUNCTION IF EXISTS geocoding_edit.geocoding_results_edit_check() CASCADE;
CREATE OR REPLACE FUNCTION geocoding_edit.geocoding_results_edit_check() RETURNS trigger AS 
$$
   DECLARE 
	affected_row_nb int := 0 ;
	_useless record ; 
    BEGIN

	-- only workingon update. No inserting allowed, no deleting allowed
	IF TG_OP = 'UPDATE' OR TG_OP = 'INSERT' THEN 
	 
		UPDATE  geocoding_edit.geocoding_results AS gr SET (historical_name, normalised_name
	,   geom  ) = (NEW.historical_name, NEW.normalised_name , NEW.geom ) 
	WHERE gr.gid = NEW.gidg 
		AND gr.ruid = NEW.ruid     --this is the security to prevent a user to change other users stuff  
        ;
		GET DIAGNOSTICS affected_row_nb := ROW_COUNT; 
		 -- filling the definite table of results with an upsert :
		IF (TG_OP = 'INSERT' OR 
			TG_OP='UPDATE' AND (ST_Distance(ST_Transform(NEW.geom,2154),ST_transform(OLD.geom,2154))>0.1 OR NEW.historical_name != OLD.historical_name OR NEW.normalised_name != OLD.normalised_name)
		)THEN 
		
		--RAISE WARNING 'toto' ;
		WITH updating AS (
			UPDATE geocoding_edit.user_edit_added_to_geocoding As loc SET 
				(historical_name, normalised_name, geom, historical_source, numerical_origin_process, ruid) = 
				(NEW.historical_name, NEW.normalised_name, ST_Transform(NEW.geom,2154),NEW.historical_source, 'website_interactive_edit_v1', NEW.ruid )
			WHERE loc.gid = NEW.gid 
			RETURNING NEW.gid)
		,inserting AS (
		INSERT INTO geocoding_edit.user_edit_added_to_geocoding 
			(gid, historical_name, normalised_name, geom, historical_source, numerical_origin_process, ruid,input_adresse_query)
			SELECT NEW.gid, NEW.historical_name, NEW.normalised_name,  ST_Transform(NEW.geom,2154),NEW.historical_source, 'website_interactive_edit_v1'::text, NEW.ruid, NEW.input_adresse_query 
			WHERE NOT EXISTS (SELECT 1 FROM updating LIMIT 1)
			RETURNING 1 )
		SELECT 1 INTO  _useless
		FROM inserting; 
		END IF; 
		--RAISE NOTICE 'affected_row : %', affected_row_nb;
		RETURN NEW;
        ELSE
		RAISE WARNING 'TG_OP: % , input : % ', TG_OP,OLD; 
		RETURN OLD ;
        END IF ;
    END;
$$ LANGUAGE plpgsql VOLATILE;

CREATE TRIGGER geocoding_results_edit_check INSTEAD OF UPDATE OR INSERT OR DELETE ON geocoding_edit.geocoding_results_v
    FOR EACH ROW EXECUTE PROCEDURE geocoding_edit.geocoding_results_edit_check();

-- testing
SELECT *, st_astext(geom)
FROM geocoding_edit.geocoding_results
WHERE ruid ILIKE 'fa60f3f4251a%' ;  

UPDATE geocoding_edit.geocoding_results_v SET (geom, ruid) = (ST_Translate(geom,0.0001,0.0001),'205d59b51ebc1935c209ca395361183c') 
WHERE gid=1 ; 

DELETE FROM geocoding_edit.geocoding_results_v  
WHERE gid=1 ; 

WITH to_be_updated AS (
	SELECT *
	FROM geocoding_edit.geocoding_results_v  
	WHERE ruid ILIKE 'fa60f3f4251a%'
	LIMIT 1
)
INSERT INTO geocoding_edit.geocoding_results_v  
SELECT * FROM to_be_updated;  

SELECT *
FROM historical_geocoding.precise_localisation 
WHERE numerical_origin_process = 'website_interactive_edit_v1'
LIMIT 1 

INSERT INTO "geocoding_edit"."geocoding_results_v" ( "gidg", input_adresse_query,"rank","historical_name","normalised_name","fuzzy_date","geom","historical_source","numerical_origin_process","semantic_distance","temporal_distance","number_distance","scale_distance","spatial_distance","aggregated_distance","spatial_precision","confidence_in_result","ruid","gid" ) 
	VALUES (  348, '12 rue du temple, PARIS; 1876',1,'12 rue du temple bla','12 rue du temple, Paris','[1783-05-30,1799-01-01)',ST_GeomFromText('POINT (2.3525655269622803 48.858835228314476)', 4326),'poubelle_municipal_paris','poubelle_paris_number',0.0,28.0,0.0,0.0,0.0,3.14999,3.5,1.0,'fbc92eda4214e14ee5e578608172d101',348)


SELECT *
FROM geocoding_edit.geocoding_results_v
TRUNCATE geocoding_edit.geocoding_results CASCADE

SELECT st_astext(geom), *
FROM geocoding_edit.geocoding_results  
WHERE ruid ILIKE 'b245ff537415df5%';   

UPDATE geocoding_edit.geocoding_results_v SET (normalised_name, ruid)
= ('test_updating','0a126da8817b4fbd4191e7ba4e70dc52')
WHERE  ruid ILIKE '0a126da88%';

SELECT st_astext(geom), *
FROM geocoding_edit.geocoding_results  
WHERE ruid ILIKE 'bd11ece9ce5324ed2a75e74e257dc3b0%';   

 
/*

DROP TABLE IF EXISTS geocoding_edit.geocoding_results_proxy ; 
CREATE TABLE IF NOT EXISTS geocoding_edit.geocoding_results_proxy (
	rank serial primary key
	, historical_name text
	, normalised_name text
	, geom geometry(point,4326)
	, historical_source text
	, aggregated_distance float
	, spatial_precision float
	, confidence_in_result float
	, approx_date date
);
INSERT INTO geocoding_edit.geocoding_results_proxy 
SELECT rank, historical_name, normalised_name, ST_Transform(ST_GeometryN(St_CollectionExtract(geom,1),1),4326)::geometry(point,4326) AS geom
	, historical_source, aggregated_distance, spatial_precision, confidence_in_result 
	, to_date(hs.default_fuzzy_date::float::int::text,'yyyy') approx_date --adding an approx date for test with geoserver
FROM geocoding_edit.geocoding_results AS gr
	LEFT OUTER JOIN geohistorical_object.historical_source AS hs ON (gr.historical_source = hs.short_name);

-- SELECT ((max(rank)+1)::int) FROM geocoding_edit.geocoding_results_proxy  ;
ALTER SEQUENCE geocoding_edit.geocoding_results_proxy_rank_seq   RESTART WITH 57 ; 
 
-- creating a trigger on geocoding_edit.geocoding_results_proxy so as to insert the de


DROP TABLE IF EXISTS geocoding_edit.monitoring; 
CREATE TABLE IF NOT EXISTS geocoding_edit.monitoring (
	rank serial primary key
	, historical_name text
	, normalised_name text
	, geom geometry(point,4326)
	, historical_source text
	, aggregated_distance float
	, spatial_precision float
	, confidence_in_result float
	, approx_date date
);

DROP TABLE IF EXISTS geocoding_edit.monitoring; 
CREATE TABLE IF NOT EXISTS geocoding_edit.monitoring AS 
SELECT pid, 'start'::text as operation, usename,application_name, client_addr, client_port, backend_start, xact_start 
	,now() as now	 
	,to_hex(trunc(EXTRACT(EPOCH FROM backend_start))::integer) || '.' || to_hex(pid) AS uid
FROM pg_stat_activity WHERE pid = pg_backend_pid();


SELECT *
FROM geocoding_edit.monitoring 
ORDER BY now;

*/
/*
 
INSERT INTO geocoding_edit.monitoring SELECT pid, 'start'::text as operation, usename,application_name, client_addr, client_port, backend_start, xact_start 
	,now() as now	 
	,to_hex(trunc(EXTRACT(EPOCH FROM backend_start))::integer) || '.' || to_hex(pid) AS uid
FROM pg_stat_activity WHERE pid = pg_backend_pid();

 
INSERT INTO geocoding_edit.monitoring SELECT pid, 'stop'::text as operation, usename,application_name, client_addr, client_port, backend_start, xact_start 
	,now() as now	 
	,to_hex(trunc(EXTRACT(EPOCH FROM backend_start))::integer) || '.' || to_hex(pid) AS uid
FROM pg_stat_activity WHERE pid = pg_backend_pid();

*/
