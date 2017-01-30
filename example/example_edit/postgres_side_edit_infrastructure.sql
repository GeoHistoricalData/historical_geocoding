---- Remi Cura, IGN, Copyright 2017
--

CREATE SCHEMA IF NOT EXISTS geocoding_edit; 
-- example of creating a result table for edit with geoserver and leaflet via WFS-T

-- creating an example table
DROP TABLE IF EXISTS geocoding_edit.geocoding_results;
CREATE TABLE IF NOT EXISTS geocoding_edit.geocoding_results 
(
  gid serial primary key,
  rank integer NOT NULL,
  historical_name text,
  normalised_name text,
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


INSERT INTO geocoding_edit.geocoding_results
SELECT row_number() over() as gid, rank, historical_name, normalised_name
	, ST_Centroid(ST_Transform(ST_GeometryN(St_CollectionExtract(geom,1),1),4326))::geometry(point,4326) AS geom
	, historical_source, numerical_origin_process
	,semantic_distance,  temporal_distance, number_distance, scale_distance,spatial_distance
	, aggregated_distance, spatial_precision, confidence_in_result
	, CASE WHEN rank %2= 0 THEN ruid1::text ELSE ruid2 END AS ruid 
FROM historical_geocoding.geocode_name_foolproof(
	query_adress:='14 rue temple, paris'
	, query_date:= sfti_makesfti('1872-11-15'::date) -- sfti_makesftix(1872,1873,1880,1881)  -- sfti_makesfti('1972-11-15');
	, use_precise_localisation := true 
	, ordering_priority_function := '100*(semantic_distance) + 0.1 * temporal_distance + 1* number_distance + 0.1 *spatial_precision + 0.001 * scale_distance +  0.0001 * spatial_distance'
	, max_number_of_candidates := 100
	, max_semantic_distance := 0.3
		, temporal_distance_range := sfti_makesfti(1820,1820,2100,2100) 
		, optional_scale_range := numrange(0,100)
		, optional_reference_geometry := NULL -- ST_Buffer(ST_GeomFromText('POINT(652208.7 6861682.4)',2154),5)
		, optional_max_spatial_distance := 10000
) AS  f, geocoding_edit.make_ruid()as ruid1, geocoding_edit.make_ruid()as ruid2  ; 

SELECT *
FROM geocoding_edit.geocoding_results ;


-- creating a view, necessary as a wrapper for trigger, allow to avoid having trigger directly on the base table, and ths separate edit coming from user and edit coming from refresh
DROP VIEW IF EXISTS geocoding_edit.geocoding_results_v ;  
CREATE VIEW geocoding_edit.geocoding_results_v AS 
SELECT gid, rank, historical_name, normalised_name
	,   geom
	, historical_source, numerical_origin_process
	,semantic_distance,  temporal_distance, number_distance, scale_distance,spatial_distance
	, aggregated_distance, spatial_precision, confidence_in_result 
	,  substring(ruid,1,12) as ruid
FROM geocoding_edit.geocoding_results ;  

SELECT *
FROM geocoding_edit.geocoding_results_v  ; 

-- creating a function to generate unique random id
DROP FUNCTION IF EXISTS geocoding_edit.make_ruid()  ; 
CREATE OR REPLACE  FUNCTION geocoding_edit.make_ruid() RETURNS text AS $$ -- found on internet
BEGIN
	RETURN md5(''||timeofday()::text||(random()*10000)::int::text);
END;
$$ LANGUAGE PLPGSQL VOLATILE CALLED ON NULL INPUT;
/*
	SELECT s, geocoding_edit.make_ruid()
	FROM generate_series(1,10) AS s  ;
*/
	
-----------
-- adding a trigger on geocoding_edit.geocoding_results_v : when updating, update geocoding_edit.geocoding_results only if the ruid matches !

DROP FUNCTION IF EXISTS geocoding_edit.geocoding_results_edit_check() CASCADE;
CREATE FUNCTION geocoding_edit.geocoding_results_edit_check() RETURNS trigger AS 
$$
    BEGIN
	-- only workingon update. No inserting allowed, no deleting allowed
	IF TG_OP = 'UPDATE' THEN 
	 
		UPDATE  geocoding_edit.geocoding_results AS gr SET (historical_name, normalised_name
	,   geom
	, historical_source, numerical_origin_process
	,semantic_distance,  temporal_distance, number_distance, scale_distance,spatial_distance
	, aggregated_distance, spatial_precision, confidence_in_result ) = (NEW.historical_name, NEW.normalised_name
	,   NEW.geom
	, NEW.historical_source, NEW.numerical_origin_process
	,NEW.semantic_distance,  NEW.temporal_distance, NEW.number_distance, NEW.scale_distance,NEW.spatial_distance
	, NEW.aggregated_distance, NEW.spatial_precision, NEW.confidence_in_result  ) 
	WHERE gr.gid = NEW.gid AND gr.ruid = NEW.ruid ;   
        RETURN NEW;
        ELSE  
		RETURN OLD ;
        END IF ;
    END;
$$ LANGUAGE plpgsql VOLATILE;

CREATE TRIGGER geocoding_results_edit_check INSTEAD OF UPDATE OR INSERT OR DELETE ON geocoding_edit.geocoding_results_v
    FOR EACH ROW EXECUTE PROCEDURE geocoding_edit.geocoding_results_edit_check();

-- testing
SELECT *, st_astext(geom)
FROM geocoding_edit.geocoding_results
WHERE gid = 1 ;  

UPDATE geocoding_edit.geocoding_results_v SET (geom, ruid) = (ST_Translate(geom,0.0001,0.0001),'205d59b51ebc1935c209ca395361183c') 
WHERE gid=1 ; 

DELETE FROM geocoding_edit.geocoding_results_v  
WHERE gid=1 ; 




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


/*here we could generate the temporary table */
INSERT INTO geocoding_edit.monitoring SELECT pid, 'start'::text as operation, usename,application_name, client_addr, client_port, backend_start, xact_start 
	,now() as now	 
	,to_hex(trunc(EXTRACT(EPOCH FROM backend_start))::integer) || '.' || to_hex(pid) AS uid
FROM pg_stat_activity WHERE pid = pg_backend_pid();


/*here we could generate the temporary table */
INSERT INTO geocoding_edit.monitoring SELECT pid, 'stop'::text as operation, usename,application_name, client_addr, client_port, backend_start, xact_start 
	,now() as now	 
	,to_hex(trunc(EXTRACT(EPOCH FROM backend_start))::integer) || '.' || to_hex(pid) AS uid
FROM pg_stat_activity WHERE pid = pg_backend_pid();

