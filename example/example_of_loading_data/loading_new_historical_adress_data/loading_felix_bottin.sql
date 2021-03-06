﻿------------------------
-- Remi Cura, 2016 , Projet Belle Epoque
------------------------

-- load the data extracted automatically from bottin by Theo from EPITA


DROP SCHEMA  IF EXISTS felix_bottin;

CREATE SCHEMA IF NOT EXISTS felix_bottin  ;

SET search_path to felix_bottin, public ; 


DROP TABLE IF EXISTS felix_bottin.bottin_raw ;
CREATE TABLE felix_bottin.bottin_raw
(
  raw_content json
); 
DROP TABLE IF EXISTS felix_bottin.bottin_raw2 ;
CREATE TABLE felix_bottin.bottin_raw2
(
    gid serial primary key,
    id text,
    lines_0 text,
    name_0 text,
    raw_c text,
    street_0 text,
    street_number_0 text,
    years_0 text,
    lines_1 text 
); 
 
 
COPY bottin_raw
FROM '/media/sf_RemiCura/DATA/Donnees_belleepoque/pour_serveur/data_to_be_geolocalised/epita_extraction_bottin_full_auto.json' ;

TRUNCATE bottin_raw2; 
COPY bottin_raw2 (id ,lines_0 ,name_0 ,raw_c ,street_0 ,street_number_0 ,years_0 ,lines_1)
--FROM '/home/ghdbguest/data/32_years_2017-03-23.json'
FROM '/media/sf_RemiCura/DATA/Donnees_belleepoque/theo/results_cleaned.csv'
CSV DELIMITER ';' ENCODING 'LATIN1' HEADER;


SELECT *
FROM bottin_raw2
LIMIT 100

SELECT raw_content->>'id' bottin_id, raw_content->>'name' street_name, raw_content->>'raw' raw 
	,regexp_matches(raw_content->>'street number','\[.*?"(.*)".*?]') AS street_number
	, regexp_matches(raw_content->>'street','\[.*?"(.*)".*?]') AS street
	, regexp_matches(raw_content->>'years','\[.*?"(.*)".*?]') AS years 
FROM bottin_raw
LIMIT 10 ; 

DROP TABLE IF EXISTS bottin_cleaned ;
CREATE TABLE IF NOT EXISTS bottin_cleaned AS
	WITH cleaned AS (
		SELECT row_number() over() as gid
			, raw_content->>'id' bottin_id
			, raw_content->>'name' street_name
			, raw_content->>'raw' raw 
			,regexp_matches(raw_content->>'street number','\[.*?"(.*)".*?]') AS street_number
			, regexp_matches(raw_content->>'street','\[.*?"(.*)".*?]') AS street
			, regexp_split_to_array((regexp_matches(raw_content->>'years','\[.*?"(.*)".*?]'))[1] , '-') AS years  
			--, sfti_makesfti(years[1]::int -1, years[1]::int , years[array_length(years,1)]::int , years[array_length(years,1)]::int +1) AS years
		FROM bottin_raw
	)
	SELECT *
		,  sfti_makesfti(years[1]::int -1, years[1]::int , years[array_length(years,1)]::int , years[array_length(years,1)]::int +1) AS fuzzy_date
	FROM cleaned ;


-- starting geocoding : 

 /*
DROP TABLE IF EXISTS bottin_geocoded ;
CREATE TABLE bottin_geocoded AS 
-- INSERT INTO bottin_geocoded
SELECT gid, bottin_id
	, postal_normalize(addr) as normalised_target_addr
	, f.* 
	,  St_Multi(ST_Buffer(f.geom, f.spatial_precision))::geometry(multipolygon,2154) AS fuzzy_geom
FROM bottin_cleaned
	 ,CAST(street_number[1]::text||' '::text||street[1]::text AS text) AS addr
	, historical_geocoding.geocode_name_optimised(
		query_adress:=addr
		, query_date:= fuzzy_date
		, use_precise_localisation := true  
		, ordering_priority_function := '100*(semantic_distance) + 0.1 * temporal_distance + 0.1 *spatial_precision + 0.001 * scale_distance +  0.0001 * spatial_distance'
		, max_number_of_candidates := 1
		, max_semantic_distance := 0.3 
		, temporal_distance_range:= sfti_makesfti(1820,1820,2000,2000)
			, optional_scale_range := numrange(0,100)
			, optional_reference_geometry := NULL -- ST_Buffer(ST_GeomFromText('POINT(652208.7 6861682.4)',2154),5)
			, optional_max_spatial_distance := 10000
) AS  f  ;
*/
--WHERE gid BETWEEN 4001 AND 4002;  
-- 37min 37 sec
-- SELECT 6308 / 6467.0 

/*
SELECT historical_source, 1.0 *count(*)  / tc  
FROM bottin_geocoded, (SELECT count(*) tc FROM bottin_geocoded ) as tc 
GROUP BY tc , historical_source
LIMIT 100 ; 
*/
/*
DROP TABLE IF EXISTS visu_date_input ; 
CREATE TABLE IF NOT EXISTS visu_date_input  AS
SELECT row_number() over() AS qgis_id, ST_SetSRID(ST_MakeValid(fuzzy_date::geometry(polygon,0)),2154) AS geom
FROM bottin_geocoded
	LEFT OUTER JOIN bottin_cleaned USING (gid)
LIMIT 100 ;
ALTER TABLE visu_date_input ADD PRIMARY KEY (qgis_id)  ; 
*/
 /*

	DROP TABLE IF EXISTS source_time_histogram ; 
	CREATE TABLE source_time_histogram AS
	WITH tref AS (
		SELECT s, ST_Buffer(ST_MakePoint(s,0.5),0.5,'quad_segs=2') as tref
		FROM generate_series(1800,2000) as s 
	)
	SELECT s,tref, count(*)  as c 
	FROM tref, bottin_geocoded
		LEFT OUTER JOIN bottin_cleaned USING (gid)
		, ST_MakeValid(fuzzy_date::geometry(polygon,0)) aS tgeom
	WHERE ST_Intersects(tref, tgeom) = TRUE
	GROUP BY s , tref ; 


	DROP TABLE IF EXISTS time_reference ;
	CREATE TABLE time_reference AS 
	SELECT s, ST_MakePoint(s,-2) AS geom
	FROM generate_series(1800,2000,25) as  s ; 
*/




DROP TABLE IF EXISTS bottin_geocoded2 ;
CREATE TABLE bottin_geocoded2 AS 


                                 
DROP TABLE IF EXISTS bottin_geocoded2;  
CREATE TABLE bottin_geocoded2 AS 

 
DECLARE @I; -- Variable names begin with a @
SET @I = 0; -- @I is an integer
WHILE @I < 19000
BEGIN 

	INSERT INTO bottin_geocoded2  
	SELECT gid,clock_timestamp(), adr_geocode, fuzzy_date AS input_date, f.*
	FROM (SELECT gid, name_0, adr_geocode, fuzzy_date
	    FROM felix_bottin.bottin_raw2
		, CAST(COALESCE(street_number_0||' ','')|| street_0||' , Paris' AS text) AS add0
		, regexp_replace(add0, 'boul.', 'boulevard') as adr_geocode
		, sfti_makesfti(years_0::int-1, years_0::int, years_0::int+1) AS fuzzy_date
	    WHERE    street_0 is not null
	    AND gid > 1
	    AND gid BETWEEN @I and @I +99) AS idata 
	  , historical_geocoding.geocode_name_foolproof(
		query_adress:=adr_geocode
		, query_date:= fuzzy_date
		, use_precise_localisation := true 
		, ordering_priority_function := '100*(semantic_distance) + 0.1 * temporal_distance + 1* number_distance + 0.1 *spatial_precision + 0.001 * scale_distance +  0.0001 * spatial_distance'
		, max_number_of_candidates := 1
		, max_semantic_distance := 0.5
			, temporal_distance_range := sfti_makesfti(1800,1800,2100,2100) 
	) AS  f   ; 

   SET @I = @I + 100;
END
-- 4h53'14''
-- 17594 sec for 18019 addresses, 17878 with existing street name
-- 17292 found
SELECT count(*)
FROM felix_bottin.bottin_raw2
WHERE street_0 is not null and years_0 is not null; 

SELECT count(*)
FROM bottin_geocoded2