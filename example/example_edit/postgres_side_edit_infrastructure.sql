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
CREATE VIEW geocoding_edit.geocoding_results_v AS 
SELECT *
FROM geocoding_edit.geocoding_results ; 


