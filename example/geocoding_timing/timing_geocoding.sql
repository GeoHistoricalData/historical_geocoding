-- working onc Carole
-------------

SELECT *
FROM stagesig.carole
	, CAST(COALESCE(num_rue || ' ','')
	|| COALESCE(type_rue || ' ','')
	|| COALESCE(article_rue || ' ','')
	|| COALESCE(nom_rue ,'')
	||', Paris' AS text) AS address
LIMIT 100


DROP TABLE IF EXISTS stagesig.results_carole2_for_timing; 
CREATE TABLE stagesig.results_carole2_for_timing AS 
SELECT id, address, annee_source AS input_date, f.*
FROM stagesig.carole2_result_geocoding, 
	CAST(COALESCE(num_rue || ' ','')
	|| COALESCE(type_rue || ' ','')
	|| COALESCE(article_rue || ' ','')
	|| COALESCE(nom_rue ,'')
	||', Paris' AS text) AS address, historical_geocoding.geocode_name_foolproof(
	query_adress:=address
	, query_date:= sfti_makesfti(COALESCE(annee_source::int,1870)) -- sfti_makesftix(1872,1873,1880,1881)  -- sfti_makesfti('1972-11-15');
	, use_precise_localisation := true 
	, ordering_priority_function := '100*(semantic_distance) + 0.1 * temporal_distance + 1* number_distance + 0.1 *spatial_precision + 0.001 * scale_distance +  0.0001 * spatial_distance'
	, max_number_of_candidates := 1
	, max_semantic_distance := 0.3
		, temporal_distance_range := sfti_makesfti(1800,1800,2100,2100) 
		 
) AS  f  
LIMIT 1000;
-- 1'54 pour 1k

SELECT *
FROM stagesig.carole_result_geocoding
LIMIT 1 

SELECT geocoder_type--, geocoder_source
	, 
	count(*) as c 
FROM stagesig.carole2_result_geocoding
GROUP BY geocoder_type--, geocoder_source
LIMIT 1


-----------------
-- working on results_helena

SELECT count(*)
FROM stagesig.results_helena
LIMIT 1 


DROP TABLE IF EXISTS stagesig.results_helena_for_timing; 
CREATE TABLE stagesig.results_helena_for_timing AS 
SELECT id_nouveau, name_concat, "Année nac" AS input_date, f.*
FROM stagesig.results_helena, historical_geocoding.geocode_name_foolproof(
	query_adress:=name_concat
	, query_date:= sfti_makesfti("Année nac"::int) -- sfti_makesftix(1872,1873,1880,1881)  -- sfti_makesfti('1972-11-15');
	, use_precise_localisation := true 
	, ordering_priority_function := '100*(semantic_distance) + 0.1 * temporal_distance + 1* number_distance + 0.1 *spatial_precision + 0.001 * scale_distance +  0.0001 * spatial_distance'
	, max_number_of_candidates := 1
	, max_semantic_distance := 0.3
		, temporal_distance_range := sfti_makesfti(1800,1800,2100,2100) 
		 
) AS  f  
LIMIT 1000 ;


SELECT *
FROM stagesig.results_helena_for_timing
LIMIT 1 
-- 13493 found voer 13991
-- 1k : 137 sec

SELECT historical_source , numerical_origin_process
	, 
	count(*) as c 
FROM stagesig.results_elena_edit
GROUP BY historical_source , numerical_origin_process


--------------------------------------
-- isabelle

SELECT *-- count(*)
FROM stagesig.isabelle
WHERE adresse_nom_1_standard IS NOT NULL
	AND adresse_nom_1_standard !=''
	AND adresse_nom_1_standard !='0'
	AND adresse_nom_1_standard !='x' 
--where voie is not null AND voie != ' ' AND voie !='rue  ' 
LIMIT 1000   
 
DROP TABLE IF EXISTS stagesig.results_isabelle_for_timing; 
CREATE TABLE stagesig.results_isabelle_for_timing AS 

WITH i_d AS (
SELECT *
FROM stagesig.isabelle
WHERE  adresse_nom_1_standard IS NOT NULL
	AND adresse_nom_1_standard !=''
	AND adresse_nom_1_standard !='0'
	AND adresse_nom_1_standard !='x' 
OFFSET 5000
LIMIT 1000  
)
SELECT id, name_concat, "année" AS input_date, f.*
FROM i_d, historical_geocoding.geocode_name_foolproof(
	query_adress:=name_concat
	, query_date:= sfti_makesfti("année"::int) -- sfti_makesftix(1872,1873,1880,1881)  -- sfti_makesfti('1972-11-15');
	, use_precise_localisation := 
		CASE WHEN "adresse numéro" != '' THEN true ELSE false END
	, ordering_priority_function := '100*(semantic_distance) + 0.1 * temporal_distance + 1* number_distance + 0.1 *spatial_precision + 0.001 * scale_distance +  0.0001 * spatial_distance'
	, max_number_of_candidates := 1
	, max_semantic_distance := 0.3
		, temporal_distance_range := sfti_makesfti(1800,1800,2100,2100) 
		 
) AS  f  ;   

SELECT historical_source , numerical_origin_process
	, 
	count(*) as c 
FROM stagesig.result_isabelle
GROUP BY historical_source , numerical_origin_process


-- --------------------------------------
-- pascal



SELECT adr_geocode, "#ADR_per"
FROM stagesig.pascal
WHERE adr_geocode NOT ILIKE 'NSP%'
LIMIT 1 



DROP TABLE IF EXISTS stagesig.results_pascal_for_timing; 
CREATE TABLE stagesig.results_pascal_for_timing AS 
SELECT id, adr_geocode, "#ADR_per" AS input_date, f.*
FROM stagesig.pascal, historical_geocoding.geocode_name_foolproof(
	query_adress:=adr_geocode
	, query_date:= sfti_makesfti(COALESCE("#ADR_per"::int,1870)) -- sfti_makesftix(1872,1873,1880,1881)  -- sfti_makesfti('1972-11-15');
	, use_precise_localisation := true 
	, ordering_priority_function := '100*(semantic_distance) + 0.1 * temporal_distance + 1* number_distance + 0.1 *spatial_precision + 0.001 * scale_distance +  0.0001 * spatial_distance'
	, max_number_of_candidates := 1
	, max_semantic_distance := 0.3
		, temporal_distance_range := sfti_makesfti(1800,1800,2100,2100) 
) AS  f  
WHERE adr_geocode NOT ILIKE 'NSP%'
LIMIT 1000 ;


-- --------------------------------------
-- working on felix bottin

SELECT *
FROM felix_bottin.bottin_cleaned
LIMIT 100; 
                                 
DROP TABLE IF EXISTS timing_bottin;  
CREATE TABLE timing_bottin AS 
WITH idata AS (
    SELECT * 
    FROM felix_bottin.bottin_cleaned
    WHERE  random()>0.75
    	AND street is not null
    LIMIT 500
)
SELECT gid,clock_timestamp(), adr_geocode, fuzzy_date AS input_date, f.*
FROM idata
  ,CAST( COALESCE(street_number[1]|| ' ','')||street[1]|| ', Paris' AS text) AS adr_geocode
  , historical_geocoding.geocode_name_foolproof(
	query_adress:=adr_geocode
	, query_date:= fuzzy_date
	, use_precise_localisation := true 
	, ordering_priority_function := '100*(semantic_distance) + 0.1 * temporal_distance + 1* number_distance + 0.1 *spatial_precision + 0.001 * scale_distance +  0.0001 * spatial_distance'
	, max_number_of_candidates := 1
	, max_semantic_distance := 0.5
		, temporal_distance_range := sfti_makesfti(1800,1800,2100,2100) 
) AS  f   ; 

SELECT '2017-03-20 14:36:07.569972+01'::timestamp - '2017-03-20 14:38:29.703992+01'::timestamp
SELECT  historical_source, numerical_origin_process, count(*) as c 
FROM timing_bottin
GROUP BY historical_source, numerical_origin_process
LIMIT 10
                    

                                 SELECT *
                                 FROM timing_bottin

with min_c as (
  select clock_timestamp 
  FROM timing_bottin
  where gid in (select min(gid) from timing_bottin )
)
, max_c AS 
(
  select clock_timestamp 
  FROM timing_bottin
  where gid in ( select max(gid) from timing_bottin )
)
SELECT EXTRACT(EPOCH FROM (max_c.clock_timestamp - min_c.clock_timestamp) ) *2
FROM min_c, max_c ;
                                 
             --351                    
                                 
                                 WITH first_now as (
                                     select clock_timestamp()
                                     )
                                 , second_now as (
                                     select clock_timestamp()
                                    )
                                 , do_something AS (
                                     SELECT 1
									FROM first_now,second_now )
                                 , end_now AS (
                                      select clock_timestamp()
                                     FROM do_something
                                     LIMIT 1 
                                     )
                                 SELECT *
                                 FROM first_now,second_now,do_something,
                                  end_now ;
                                 
                                 
SELECT count(*) c
FROM felix_bottin.bottin_geocoded
LIMIT 1 ;
                                 
                                 
                                 						  
SELECT  historical_source, numerical_origin_process , count(*)::float/(SELECT count(*) FROM  stagesig.result_isabelle) as  c
FROM stagesig.result_isabelle
GROUP BY  historical_source, numerical_origin_process
LIMIT 1
