---- Remi Cura, IGN, Copyright 2017
--

CREATE SCHEMA IF NOT EXISTS geocoding_edit; 
-- example of creating a result table for edit with geoserver and leaflet via WFS-T

-- creating an example table
DROP TABLE IF EXISTS geocoding_edit.geocoding_results;
CREATE TABLE IF NOT EXISTS geocoding_edit.geocoding_results AS
SELECT f.*
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
) AS  f  ;
ALTER TABLE geocoding_edit.geocoding_results ADD PRIMARY KEY (rank) ; 

SELECT *
FROM geocoding_edit.geocoding_results ;


-- creating a view, necessary as a wrapper for trigger, allow to avoid having trigger directly on the base table, and ths separate edit coming from user and edit coming from refresh
DROP TABLE IF EXISTS geocoding_edit.geocoding_results_v ;  
CREATE TABLE geocoding_edit.geocoding_results_v AS 
SELECT rank, historical_name, normalised_name, ST_Transform(ST_GeometryN(St_CollectionExtract(geom,1),1),4326)::geometry(point,4326) AS geom
	, historical_source, aggregated_distance, spatial_precision, confidence_in_result
FROM geocoding_edit.geocoding_results ; 
ALTER TABLE geocoding_edit.geocoding_results_v ADD PRIMARY KEY(rank)  ; 


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

