------------------------
-- Remi Cura, 2016 , Projet Belle Epoque
------------------------


-- geocoding api

--utilitary function to sanitize API text input : remove all kind of commentary
 
DROP FUNCTION IF EXISTS historical_geocoding.sanitize_input( itext text) ; 
CREATE OR REPLACE FUNCTION historical_geocoding.sanitize_input( itext text) RETURNS TEXT AS $BODY$
		--@brief : this function takes an input text and remove everything looking like a comment, or 'SELECT ', 'UPDATE', ALTER, DROP INSERT  
		DECLARE   
			_cleaned text ; 
			_tc text ; 
		BEGIN 
			_cleaned := replace(replace(replace(replace(itext, '$', ''),'-',''),'/*',''),'*/','');
 
		--loop : if we find a chr or /*, remove it, loop
		 
		LOOP
			_tc := _cleaned ;
		    _cleaned := regexp_replace(_cleaned, '/*', '','ig') ;  --remove all nested /*  candidates 
		    _cleaned := regexp_replace(_cleaned, 'chr\(', '','ig') ; -- rmeove all chr(
		    _cleaned := regexp_replace(_cleaned, 'SELECT', '','ig') ; -- rmeove all dangerous SQL command
		    _cleaned := regexp_replace(_cleaned, 'UPDATE', '','ig') ;  
		    _cleaned := regexp_replace(_cleaned, 'ALTER', '','ig') ;  
		    _cleaned := regexp_replace(_cleaned, 'DROP', '','ig') ;  
		    _cleaned := regexp_replace(_cleaned, 'DELETE', '','ig') ; 
		    _cleaned := regexp_replace(_cleaned, 'INSERT', '','ig') ;  
		    _cleaned := regexp_replace(_cleaned, 'COPY', '','ig') ;  
		    
		    IF _tc = _cleaned THEN EXIT; END IF;
		END LOOP  ; 
		RETURN  _cleaned ; 
		END ; 
	$BODY$
LANGUAGE plpgsql  strict;  
SELECT historical_geocoding.sanitize_input(' 1=1 ;--
SELECT DROP table
/*trying to hack database -- -- - ----- /**///****// $$ $$ $$$$ chr(12) CHR(12) Chr(12) CHR/**/(12 */'); 
			 
DROP FUNCTION IF EXISTS historical_geocoding.geocode_name_base( 
	query_adress text, query_date sfti, use_precise_localisation boolean
	, ordering_priority_function text  
	, max_number_of_candidates int
	, max_semantic_distance float
	, temporal_distance_range sfti 
	, optional_scale_range numrange 
	, optional_reference_geometry geometry(multipolygon,2154)  
	, optional_spatial_distance_range float  
	); 
CREATE OR REPLACE FUNCTION historical_geocoding.geocode_name_base(
	query_adress text, query_date sfti,  use_precise_localisation boolean DEFAULT TRUE
	, ordering_priority_function text DEFAULT ' 100*(semantic_distance) + 0.1 * temporal_distance + 10* number_distance + 0.1 *spatial_precision + 0.01 * scale_distance +  0.001 * spatial_distance '
	, max_number_of_candidates int DEFAULT 10 
	, max_semantic_distance float DEFAULT 0.45
	, temporal_distance_range sfti DEFAULT sfti_makesfti(1800,1800,2100,2100) 
	, optional_scale_range numrange DEFAULT numrange(0,10000)
	, optional_reference_geometry geometry(multipolygon,2154) DEFAULT NULL
	, optional_max_spatial_distance float DEFAULT NULL)
RETURNS table(rank int,
		  historical_name text,
		  normalised_name text,
		  geom geometry,
		  specific_fuzzy_date sfti,
		  specific_spatial_precision float,
		  historical_source text ,
		  numerical_origin_process text 
	, semantic_distance float
	, temporal_distance float
	, number_distance float
	, scale_distance float
	, spatial_distance float
	, aggregated_distance float
	, spatial_precision float
	, confidence_in_result float) AS 
	$BODY$
		--@brief : this function takes an adress and date query, as well as a metric, and tries to find the best match in the database 
		--@param : there is a 4th optional distance : spatial distance. In this one, the user shall provide a geometry, then results are evaluated also based on the geodesic dist ot thi surface.
		
		DECLARE 
			_sql text := NULL ; 
			_precise_or_rough_name text  := 'precise';
		BEGIN  
			
			-- the minimal allowed semantic distance is used in indexing, as such it is quite essential
			EXECUTE format('SELECT set_limit(1-%s) ;',max_semantic_distance) ; 
			IF use_precise_localisation IS FALSE THEN 
				_precise_or_rough_name := 'rough' ; 
			END IF ; 

			--basic sanitizing of user input for ordering function
			ordering_priority_function := historical_geocoding.sanitize_input(ordering_priority_function) ;  
			

			
			_sql := format('SELECT (row_number() over(order by aggregated_score ASC))::int as rank,
					 rl.historical_name , rl.normalised_name  ,  rl.geom  ,   rl.specific_fuzzy_date ,
					  rl.specific_spatial_precision ,   rl.historical_source ,   rl.numerical_origin_process 
					 
				, semantic_distance::float, temporal_distance::float,number_distance::float,  scale_distance::float, spatial_distance::float
				, aggregated_score::float
				, spatial_precision::float
				, 1::float AS confidence_in_result -- TODO : fix this confidence to mean something
			FROM  historical_geocoding.%1$s_localisation AS rl 
				LEFT OUTER JOIN geohistorical_object.historical_source as hs ON (rl.historical_source = hs.short_name)
				LEFT OUTER JOIN geohistorical_object.numerical_origin_process as hs2 ON (rl.numerical_origin_process = hs2.short_name)
				, COALESCE(1-similarity(normalised_name, $1), 0) AS semantic_distance
				, COALESCE( (sfti_distance_asym(COALESCE(rl.specific_fuzzy_date,hs.default_fuzzy_date), $2) ).fuzzy_distance,0) AS temporal_distance
				, CAST( geohistorical_object.json_spatial_precision(hs.default_spatial_precision, ''number'')+geohistorical_object.json_spatial_precision(hs2.default_spatial_precision, ''number'') AS float) AS def_spatial_precision
				, COALESCE(rl.specific_spatial_precision, def_spatial_precision) AS spatial_precision
				, least( abs(sqrt(st_area(geom))  - lower($3)),abs(sqrt(st_area(geom)) - upper($3))) AS scale_distance
				, COALESCE(ST_Distance($4::geometry, rl.geom),0) AS spatial_distance
				, postal_parse($1) as parsed_iadress
				, postal_parse(normalised_name) as parsed_adress
				, historical_geocoding.number_distance(parsed_iadress->>''house_number'', parsed_adress->>''house_number'') as number_distance
				, CAST ( %3$s AS float) AS aggregated_score
				
			WHERE 
				normalised_name %% $1 --semantic distance
				--normalised_name <-> $1 --semantic distance
				AND ST_Intersects(COALESCE(rl.specific_fuzzy_date,hs.default_fuzzy_date)::geometry , $6::geometry ) = TRUE -- time should be compativble with input max time range
				--AND sqrt(st_Area(geom))::numeric <@ $3 -- scale distance 
				AND ($4 IS NULL OR ST_DWithin($4::geometry ,rl.geom, $5)) -- the result should be within the allowed distance range to reference geometry
				
			ORDER BY aggregated_score ASC
				
			LIMIT %2$s ;',_precise_or_rough_name, max_number_of_candidates , ordering_priority_function);
			-- RAISE NOTICE '%',_sql ;
			RETURN QUERY EXECUTE _sql USING query_adress, query_date, optional_scale_range numrange , optional_reference_geometry , optional_max_spatial_distance, temporal_distance_range; 

			
		RETURN ;
		END ; 
	$BODY$
LANGUAGE plpgsql  VOLATILE CALLED ON NULL INPUT; 

--SELECT set_limit(0.7) ;

/*
SELECT f.*
FROM historical_geocoding.geocode_name_base(
	query_adress:='11 rue de la paix'
	, query_date:= sfti_makesfti('1872-11-15'::date) -- sfti_makesftix(1872,1873,1880,1881)  -- sfti_makesfti('1972-11-15');
	, use_precise_localisation := true 
	, ordering_priority_function := '100*(semantic_distance) + 0.1 * temporal_distance + 10*number_distance +  0.1 *spatial_precision + 0.001 * scale_distance +  0.0001 * spatial_distance '
	, max_number_of_candidates := 100
	, max_semantic_distance := 0.3
		, temporal_distance_range := sfti_makesfti(1820,1820,2000,2000) 
		, optional_scale_range := numrange(0,100)
		, optional_reference_geometry := NULL -- ST_Buffer(ST_GeomFromText('POINT(652208.7 6861682.4)',2154),5)
		, optional_max_spatial_distance := 10000
) AS  f  ;
*/


 SELECT *
 FROM  postal_parse('11 rue de la paix, Paris') as parsed_iadress
	, postal_parse('11 rue de la paix') as parsed_adress
	, historical_geocoding.number_distance(parsed_iadress->>'house_number', parsed_adress->>'house_number') as number_distance ; 

SELECT historical_geocoding.number_distance('11', '11') ;
		
DROP FUNCTION IF EXISTS historical_geocoding.geocode_name_optimised_inter( 
	query_adress text, query_date sfti, use_precise_localisation boolean
	, ordering_priority_function text  
	, max_number_of_candidates int
	, max_semantic_distance float
	, temporal_distance_range sfti 
	, optional_scale_range numrange 
	, optional_reference_geometry geometry(multipolygon,2154)  
	, optional_spatial_distance_range float  
	); 
CREATE OR REPLACE FUNCTION historical_geocoding.geocode_name_optimised_inter(
	query_adress text, query_date sfti,  use_precise_localisation boolean DEFAULT TRUE
	, ordering_priority_function text DEFAULT ' 100*(semantic_distance) + 0.1 * temporal_distance + 0.1 *spatial_precision + 0.01 * scale_distance +  0.001 * spatial_distance '
	, max_number_of_candidates int DEFAULT 10 
	, max_semantic_distance float DEFAULT 0.45
	, temporal_distance_range sfti DEFAULT sfti_makesfti(1800,1800,2100,2100) 
	, optional_scale_range numrange DEFAULT numrange(0,10000)
	, optional_reference_geometry geometry(multipolygon,2154) DEFAULT NULL
	, optional_max_spatial_distance float DEFAULT NULL)
RETURNS table(rank int,
		  historical_name text,
		  normalised_name text,
		  geom geometry,
		  specific_fuzzy_date sfti,
		  specific_spatial_precision float,
		  historical_source text ,
		  numerical_origin_process text 
	, semantic_distance float
	, temporal_distance float 
	, number_distance float
	, scale_distance float
	, spatial_distance float
	, aggregated_distance float
	, spatial_precision float
	, confidence_in_result float) AS 
	$BODY$
		--@brief : this function takes an adress and date query, as well as a metric, and tries to find the best match in the database 
		 
		DECLARE  
			_returned_count int := 0 ; 
		BEGIN   
			ordering_priority_function := historical_geocoding.sanitize_input(ordering_priority_function) ;  
			FOR _i in 0..10
			LOOP 
				RETURN QUERY 
					SELECT *
					FROM historical_geocoding.geocode_name_base(
						query_adress 
						, query_date 
						, use_precise_localisation  
						, ordering_priority_function  
						, max_number_of_candidates 
						, _i /10.0 
							, temporal_distance_range  
							, optional_scale_range 
							, optional_reference_geometry  
							, optional_max_spatial_distance 
					) AS  f  ;

				GET DIAGNOSTICS _returned_count = ROW_COUNT;
				-- RAISE NOTICE '_i is %, returned_count : %',_i , _returned_count; 
				EXIT WHEN _returned_count >= max_number_of_candidates OR _i/10.0 >= max_semantic_distance ;   
			END LOOP ;   
		RETURN ;
		END ; 
	$BODY$
LANGUAGE plpgsql  VOLATILE CALLED ON NULL INPUT; 



DROP FUNCTION IF EXISTS historical_geocoding.geocode_name_optimised( 
	query_adress text, query_date sfti, use_precise_localisation boolean
	, ordering_priority_function text  
	, max_number_of_candidates int
	, max_semantic_distance float
	, temporal_distance_range sfti 
	, optional_scale_range numrange 
	, optional_reference_geometry geometry(multipolygon,2154)  
	, optional_spatial_distance_range float  
	); 
CREATE OR REPLACE FUNCTION historical_geocoding.geocode_name_optimised(
	query_adress text, query_date sfti,  use_precise_localisation boolean DEFAULT TRUE
	, ordering_priority_function text DEFAULT ' 100*(semantic_distance) + 0.1 * temporal_distance + 0.1 *spatial_precision + 0.01 * scale_distance +  0.001 * spatial_distance '
	, max_number_of_candidates int DEFAULT 10 
	, max_semantic_distance float DEFAULT 0.45
	, temporal_distance_range sfti DEFAULT sfti_makesfti(1800,1800,2100,2100) 
	, optional_scale_range numrange DEFAULT numrange(0,10000)
	, optional_reference_geometry geometry(multipolygon,2154) DEFAULT NULL
	, optional_max_spatial_distance float DEFAULT NULL)
RETURNS table(rank int,
		  historical_name text,
		  normalised_name text,
		  geom geometry,
		  specific_fuzzy_date sfti,
		  specific_spatial_precision float,
		  historical_source text ,
		  numerical_origin_process text 
	, semantic_distance float
	, temporal_distance float
	, number_distance float
	, scale_distance float
	, spatial_distance float
	, aggregated_distance float
	, spatial_precision float
	, confidence_in_result float) AS 
	$BODY$
		--@brief : this function takes an adress and date query, as well as a metric, and tries to find the best match in the database 
		DECLARE  
			_returned_count int := 0  ; 
		BEGIN  
			ordering_priority_function := historical_geocoding.sanitize_input(ordering_priority_function) ;  
			 RETURN QUERY
				SELECT * 
				FROM (
				SELECT DISTINCT ON ( historical_name, normalised_name,  geom,  historical_source ,numerical_origin_process) *
				FROM historical_geocoding.geocode_name_optimised_inter(
					query_adress  , query_date  , use_precise_localisation  
					, ordering_priority_function   , max_number_of_candidates  ,  max_semantic_distance
						, temporal_distance_range   , optional_scale_range  , optional_reference_geometry   , optional_max_spatial_distance 
					) AS  f  
				ORDER BY historical_name, normalised_name,  geom,  historical_source ,numerical_origin_process, aggregated_distance 
				) AS sub
				ORDER BY rank ASC;
		RETURN ;
		END ; 
	$BODY$
LANGUAGE plpgsql  VOLATILE CALLED ON NULL INPUT; 




/*
DROP TABLE IF EXISTS historical_geocoding.test_rue_saint_jacque_rough ; 
CREATE TABLE historical_geocoding.test_rue_saint_jacque_rough  AS 
SELECT f.*
FROM historical_geocoding.geocode_name_optimised(
	query_adress:='14 rue saint jacques'
	, query_date:= sfti_makesfti('1872-11-15'::date) -- sfti_makesftix(1872,1873,1880,1881)  -- sfti_makesfti('1972-11-15');
	, use_precise_localisation := true 
	, ordering_priority_function := '100*(semantic_distance) + 0.1 * temporal_distance + 1* number_distance + 0.1 *spatial_precision + 0.001 * scale_distance +  0.0001 * spatial_distance'
	, max_number_of_candidates := 100
	, max_semantic_distance := 0.3
		, temporal_distance_range := sfti_makesfti(1820,1820,2000,2000) 
		, optional_scale_range := numrange(0,100)
		, optional_reference_geometry := NULL -- ST_Buffer(ST_GeomFromText('POINT(652208.7 6861682.4)',2154),5)
		, optional_max_spatial_distance := 10000
) AS  f  ;
*/
 




DROP FUNCTION IF EXISTS historical_geocoding.geocode_name_foolproof( 
	query_adress text, query_date sfti, use_precise_localisation boolean
	, ordering_priority_function text  
	, max_number_of_candidates int
	, max_semantic_distance float
	, temporal_distance_range sfti 
	, optional_scale_range numrange 
	, optional_reference_geometry geometry(multipolygon,2154)  
	, optional_spatial_distance_range float  
	); 
CREATE OR REPLACE FUNCTION historical_geocoding.geocode_name_foolproof(
	query_adress text, query_date sfti,  use_precise_localisation boolean DEFAULT TRUE
	, ordering_priority_function text DEFAULT '100*(semantic_distance) + 0.1 * temporal_distance + 1* number_distance + 0.1 *spatial_precision + 0.001 * scale_distance +  0.0001 * spatial_distance'
	, max_number_of_candidates int DEFAULT 10 
	, max_semantic_distance float DEFAULT 0.45
	, temporal_distance_range sfti DEFAULT sfti_makesfti(1800,1800,2100,2100) 
	, optional_scale_range numrange DEFAULT numrange(0,10000)
	, optional_reference_geometry geometry(multipolygon,2154) DEFAULT NULL
	, optional_max_spatial_distance float DEFAULT NULL)
RETURNS table(rank int,  historical_name text, normalised_name text,   geom geometry,   specific_fuzzy_date sfti,   specific_spatial_precision float, historical_source text ,  numerical_origin_process text 
	, semantic_distance float , temporal_distance float  , number_distance float 
	, scale_distance float , spatial_distance float , aggregated_distance float , spatial_precision float
	, confidence_in_result float) AS 
	$BODY$
		--@brief : this function takes an adress and date query, then first look for precise localisation, if not found, look for rough localisation
		 
		DECLARE 
			_returned_count int := 0 ; 
		BEGIN  
			ordering_priority_function := historical_geocoding.sanitize_input(ordering_priority_function) ;  
			 RETURN QUERY
			 SELECT *
			 FROM (
				SELECT DISTINCT ON ( historical_name, normalised_name,  geom,  historical_source ,numerical_origin_process) *
				FROM historical_geocoding.geocode_name_optimised_inter(
					query_adress 
					, query_date 
					, use_precise_localisation  
					, ordering_priority_function  
					, max_number_of_candidates 
					,  max_semantic_distance
						, temporal_distance_range  
						, optional_scale_range 
						, optional_reference_geometry  
						, optional_max_spatial_distance 
					) AS  f  
				ORDER BY historical_name, normalised_name,  geom,  historical_source ,numerical_origin_process, aggregated_distance
				) AS sub
				ORDER BY rank ASC, aggregated_distance ; 
			GET DIAGNOSTICS _returned_count = ROW_COUNT;

			IF (_returned_count = 0 ) AND use_precise_localisation IS TRUE THEN -- didn't found anything, looking for rough localisation
			RETURN QUERY 
				SELECT * 
				FROM (
				SELECT DISTINCT ON ( historical_name, normalised_name,  geom,  historical_source ,numerical_origin_process) *
				FROM historical_geocoding.geocode_name_optimised_inter(
					query_adress  , query_date  , false  
					, ordering_priority_function   , max_number_of_candidates  ,  max_semantic_distance
						, temporal_distance_range   , optional_scale_range  , optional_reference_geometry   , optional_max_spatial_distance 
					) AS  f  
				ORDER BY historical_name, normalised_name,  geom,  historical_source ,numerical_origin_process, aggregated_distance
				) AS sub
				ORDER BY rank ASC, aggregated_distance ; 
			END IF ;  
			
		RETURN ;
		END ; 
	$BODY$
LANGUAGE plpgsql  VOLATILE CALLED ON NULL INPUT; 

/*
SELECT f.*
FROM historical_geocoding.geocode_name_foolproof(
	query_adress:='14 rue toto'
	, query_date:= sfti_makesfti('1872-11-15'::date) -- sfti_makesftix(1872,1873,1880,1881)  -- sfti_makesfti('1972-11-15');
	, use_precise_localisation := true 
	, ordering_priority_function := '100*(semantic_distance) + 0.1 * temporal_distance + 1* number_distance + 0.1 *spatial_precision + 0.001 * scale_distance +  0.0001 * spatial_distance'
	, max_number_of_candidates := 100
	, max_semantic_distance := 0.3
		, temporal_distance_range := sfti_makesfti(1820,1820,2000,2000) 
		, optional_scale_range := numrange(0,100)
		, optional_reference_geometry := NULL -- ST_Buffer(ST_GeomFromText('POINT(652208.7 6861682.4)',2154),5)
		, optional_max_spatial_distance := 10000
) AS  f  ;
*/
/*
DROP TABLE IF EXISTS ehess_data.censitaire_lieu_contrib_geocoded ; 
CREATE TABLE IF NOT EXISTS ehess_data.censitaire_lieu_contrib_geocoded  AS
WITH distinct_lieu_contrib AS (
	SELECT lieu_contrib, count(*) AS  c
	FROM ehess_data.censitaire_raw
	WHERE char_length(lieu_contrib) > 3
	GROUP BY lieu_contrib
	ORDER BY c DESC
	OFFSET 3
	
)
SELECT dlc.*, f.rank, f.historical_name, f.normalised_name, ST_Buffer(ST_Centroid(geom), spatial_precision) AS fuzzy_localisation, f.historical_source, f.numerical_origin_process, f. semantic_distance, f.temporal_distance, f.scale_distance, f.aggregated_distance, f.spatial_precision
FROM distinct_lieu_contrib AS dlc
	, historical_geocoding.geocode_name_optimised(
		query_adress:='commune '||lieu_contrib
		, query_date:= sfti_makesfti('01/01/1848'::date) -- sfti_makesftix(1872,1873,1880,1881)  -- sfti_makesfti('1972-11-15');
		, use_precise_localisation := false 
		, ordering_priority_function := '100*(semantic_distance) + 0.1 * temporal_distance + 10*number_distance + 0.001 * scale_distance +  0.0001 * spatial_distance'
		, max_number_of_candidates := 1
		, max_semantic_distance := 0.2
			, temporal_distance_range := sfti_makesfti(1820,1820,2000,2000) 
			, optional_scale_range := numrange(100,100000)
			, optional_reference_geometry := NULL -- ST_Buffer(ST_GeomFromText('POINT(652208.7 6861682.4)',2154),5)
			, optional_max_spatial_distance := 10000
		) AS  f  ;
*/