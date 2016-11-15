------------------------
-- Remi Cura, 2016 , Projet Belle Epoque
------------------------
		--using libpostal 
	--	CREATE EXTENSION IF NOT EXISTS postal 
-- part 1 : deal with input adress query
-- the input query should be normalised and matched against database
-- in the normalise step, we should 
/*
Part 1
    This part start with a query adress and a date, provided by a user or via an automated mechanism (batch mode)
    1.1 Normalise
    1.1.1 If the query adress directly contains the adress and the date, the date and adress are separated. We use regular expression to do so. Missing date are handled at this level (a default 1850 date is added)
    1.1.2 Parse and normalise adress and date
        1.1.2.1 We parse/normalise adress using the libpostal tool. libpostal is a machine learning method trained on open street map dataset to parse french adress into structured content. In our case, it can separate the numbering part, the way part, and the city part.
        1.1.2.2 The date is parsed/normalised using the python module dateutil and regexp
        1.1.2.3 In France the numbering may contain more than number, for instance '12 Bis'. We parse and normalise that using regexp. This has been tested and validated for the whole Paris open street map current data.

1.2 Match the different element to adress database
    1.2.3 match numbering to adress database. Numbers are matched using a simple int to int distance modified to take into consideration the parity. For instance the int distance between 12 and 13 is 1, but in fact 12 is more likely to be closer to 14 if 12 is missing. Anyway the classical btree index allow efficient knn queries, but is not really needed, as the match happens first through way name, and the number of numbering per way is limited.
    1.2.1 We match the query way to the database way. It is text to text matching, in a robust way. We have several robust solutions to this end, such as the trigram approach. We use the pg_trgm extension for fast indexed robust comparison between text.
    1.2.2 Historical dates are in fact fuzzy. We choose to model the fuziness using the trapezoidal model. A new postgres data type is created accordingly, with cast to range and to postgis geometry. This allows for several indexes for fast and robust fuzzy time distance. The fuzzy distance operator we use is custom.


-------- 1.1 : Normalise ------------
	---------- 1.1.1 separate adress and date			 --------
	---------- 1.1.2 Parse and normalise adress and date	 --------
	---------- 1.1.2.1 parse/normalise adress			 --------
	---------- 1.1.2.2 parse/normalise date 				 --------
	---------- 1.1.2.3 parse/normalise numbering			 --------
	

-------- 1.2 : Match ------------
	---------- 1.2.3 match numering 					 --------
	---------- 1.2.1 match street /city name 				 --------
	---------- 1.2.2 match date 						 --------

	
*/






-------- 1.1 : Normalise ------------
	---------- 1.1.1 separate adress and date			 --------

		-- designing a simple regexp to extract date at the end
			-- date should be a year in 4 digits, that's all that's allowed   !

			SELECT ar
			FROM CAST('24, rue du Quatre-Septembre'  AS text) AS query
				,regexp_matches(trim( both ' ' from query), '(.*?)([\-_,;\s]*?)([[\d]{4}]?)([\-_,;\s]*?)') AS ar ;

			SELECT ar
			FROM CAST('24, rue du Quatre-Septembre, 1912'  AS text) AS query
				,regexp_matches(trim( both ' ' from query), '(.*?)([\-_,;\s]*?)([[\d]{4}]?)([\-_,;\s]*?)') AS ar ;

		DROP FUNCTION IF EXISTS historical_geocoding.separate_adress_and_date(adress_date_query text, OUT adress_query text, OUT date_query text, OUT separator text) ;
		CREATE OR REPLACE FUNCTION historical_geocoding.separate_adress_and_date(adress_date_query text, OUT adress_query text, OUT date_query text, OUT separator text )   AS 
		$$
			-- this function take an adress  and date query and separate it into an adress and a date.Allowed input date format is 4 digits, common separator are allowed between adress and date.
		DECLARE   
		BEGIN  
			SELECT ar[1] , ar[2], ar[3]  INTO adress_query, separator, date_query 
			FROM CAST(adress_date_query  AS text) AS query
				,regexp_matches(trim( both ' ' from query), '(.*?)([\-_,;\s]*?)([[\d]{4}]?)([\-_,;\s]*?)') AS ar ;

				IF adress_query IS NULL THEN 
				adress_query := adress_date_query ; 
				END IF;  
			RETURN ; 
		END ; 
		$$
		LANGUAGE 'plpgsql' IMMUTABLE STRICT ; 

		SELECT r.*
		FROM CAST('24, rue du Quatre-Septembre, 1912'  AS text) AS query
			, historical_geocoding.separate_adress_and_date(query) as r ; 
		
	---------- 1.1.2 Parse and normalise adress and date	 --------
	---------- 1.1.2.1 parse/normalise adress			 --------
/*

		WITH norm as (
		SELECT adress_query  
			--,postal_parse( (postal_normalize(adress_query ))[1] ) as f 
			,postal_parse( adress_query  ) as f  
		FROM (SELECT * FROM  test_extension.example_adress_query LIMIT 1000 ) as tto
		)
		SELECT
			 jsonb_extract_path_text(f,'city'::text)
			, jsonb_extract_path_text(f,'road'::text)
			, jsonb_extract_path_text(f,'house_number'::text)
		FROM norm ;

*/
		
		DROP FUNCTION IF EXISTS historical_geocoding.normalise_parse_adress(adress_query text, IN default_city TEXT , OUT city text, out road_name text, out house_number text) ;
		CREATE OR REPLACE FUNCTION historical_geocoding.normalise_parse_adress(adress_query text, IN default_city text DEFAULT 'PARIS', OUT city text, out road_name text, out house_number text) AS 
		$$
			-- this function take an adress query (and optionnaly a default city name), and return the city, road name, and house number parsed via libpostal
		DECLARE   
		BEGIN  
			SELECT   jsonb_extract_path_text(f,'city'::text)
				, jsonb_extract_path_text(f,'road'::text)
				, jsonb_extract_path_text(f,'house_number'::text)
					INTO city, road_name, house_number
			FROM  postal_parse(adress_query  ) as f ; 
			IF city IS NULL THEN 
				SELECT   jsonb_extract_path_text(f,'city'::text)
					, jsonb_extract_path_text(f,'road'::text)
					, jsonb_extract_path_text(f,'house_number'::text)
						INTO city, road_name, house_number
					FROM  postal_parse(adress_query|| ' , '||  default_city ) as f ;
				IF city IS NULL THEN  
					city := default_city ; 
				END IF ; 
			END IF ; 
				
			RETURN ; 
		END ; 
		$$
		LANGUAGE 'plpgsql' IMMUTABLE STRICT ; 
/*
		SELECT f.*
		FROM  test_extension.example_adress_query as q 
			, historical_geocoding.normalise_parse_adress(adress_query, 'PARIS'::text) as f ; 
			*/

	---------- 1.1.2.2 parse/normalise date 				 --------
		--for the moment, we only allow simple date as input (XXXX).
		-- the function is then mostly an empty shell that could be upgraded to deal with more advanced date, such as 'june 1845 to august 1832, with 2 months uncertainity'

		DROP FUNCTION IF EXISTS historical_geocoding.normalise_date(date_query text, OUT normalised_date int) ;
		CREATE OR REPLACE FUNCTION historical_geocoding.normalise_date(date_query text, OUT normalised_date int) AS 
		$$
			-- this function take a date query and normalise it to our custom fuzzy date system
			-- TODO :  for the moment, the function returns an int, it should return a custom fuzzy date type
			-- the job should be done using pllpython and the dateutil python module
		DECLARE  
		BEGIN 
			 normalised_date := date_query::text::int ; 
			RETURN ; 
		END ; 
		$$
		LANGUAGE 'plpgsql' IMMUTABLE STRICT ; 

		SELECT f.*
		FROM historical_geocoding.normalise_date(' 1895 ') AS f; 
		
	---------- 1.1.2.3 parse/normalise numbering			 --------

		-- the necessary functionnalities were arlready added in a lib file
		
		DROP FUNCTION IF EXISTS historical_geocoding.normalise_numbering(numbering_query text, OUT normalised_number int, OUT normalised_suffixe text) ; 
		CREATE OR REPLACE FUNCTION historical_geocoding.normalise_numbering(numbering_query text, OUT normalised_number int, OUT normalised_suffixe text)  AS 
		$$
			-- this function take a date query and normalise it to our custom fuzzy date system
			-- TODO :  for the moment, the function returns an int, it should return a custom fuzzy date type
			-- the job should be done using pllpython and the dateutil python module
		DECLARE   
		BEGIN  
			 SELECT f.* INTO normalised_number, normalised_suffixe
			 FROM historical_geocoding.normaliser_numerotation(numbering_query) AS f  ;
			 
			RETURN ; 
		END ; 
		$$
		LANGUAGE 'plpgsql' IMMUTABLE STRICT ; 

	SELECT f.*
	FROM  historical_geocoding.normalise_numbering('12b') AS f  ; 

-------- 1.2 : Match ------------
	--complete system  : the database has already been filled with various historical and current data
		--getting test data : 
		/*
		SELECT gid, adresse,   city, road_name, house_number
			FROM test_extension.test_sample_adress 
				, historical_geocoding.normalise_parse_adress(replace(adresse, ' R ',' rue ')|| ', Paris', 'Paris')  
			LIMIT 100 ; 
			*/

	---------- 1.2.1 match street /city name 				 --------
		--testing to find a street name :
		/*
		WITH input_adress AS (
			SELECT gid, adresse,   city, road_name, house_number, fuzzy_date
			FROM test_extension.test_sample_adress 
				, historical_geocoding.normalise_parse_adress(replace(adresse, ' R ',' rue ')|| ', Paris', 'Paris')  
			WHERE gid = 36
		)
		SELECT *, similarity(road_name, normalised_name ) 
		FROM input_adress, historical_geocoding.rough_localisation
		WHERE road_name % normalised_name
		ORDER BY road_name <-> normalised_name 
		LIMIT 100;
		*/

		--testing to find a city
		/*
		WITH input_adress AS (
			SELECT gid, adresse,   city, road_name, house_number, fuzzy_date
			FROM test_extension.test_sample_adress 
				, historical_geocoding.normalise_parse_adress(replace(adresse, ' R ',' rue ')|| ', Paris', 'Paris')  
			WHERE gid = 36
		)
		SELECT *, similarity(city, normalised_name ) 
		FROM input_adress, historical_geocoding.rough_localisation
		WHERE city % normalised_name
		ORDER BY city <-> normalised_name 
		LIMIT 100;
		*/
		

		--testing to find a quartier :
		WITH input_adress AS (
			SELECT 'quartier du Palais-Royal'::text AS quartier_name
		)
		SELECT *, similarity(quartier_name, normalised_name ) 
		FROM input_adress, historical_geocoding.rough_localisation
		WHERE quartier_name % normalised_name
		ORDER BY quartier_name <-> normalised_name 
		LIMIT 100;

	
	---------- 1.2.2 match date 						 --------
	/* -- TODO
		WITH input_adress AS (
			SELECT gid, adresse,   city, road_name, house_number, fuzzy_date
			FROM test_extension.test_sample_adress 
				, historical_geocoding.normalise_parse_adress(replace(adresse, ' R ',' rue ')|| ', Paris', 'Paris')  
			WHERE gid = 54
		)
		--SELECT sfti_distance_asym(
		*/
		
	
		
	
	---------- 1.2.3 match numbering 					 --------
		--testing the numbering match
		--numbering result is an union of 2 results
		/*
		WITH input_adress AS ( 
			SELECT gid, adresse,   city, road_name, house_number, fuzzy_date, house_number ||  ' ' ||road_name AS norm_adress
			FROM test_extension.test_sample_adress 
				, historical_geocoding.normalise_parse_adress(replace(adresse, ' R ',' rue ')|| ', Paris', 'Paris')  
			WHERE gid = 54
		)-- get numbers that directly habe in normalised_name the correct adress
		SELECT similarity(norm_adress, normalised_name) , precise_localisation.*
		FROM input_adress, historical_geocoding.precise_localisation
		WHERE norm_adress % normalised_name
			-- AND numrange(0::numeric,(ST_MinimumBoundingRadius(geom)).radius::numeric) <-> numrange(0,30)
		ORDER BY norm_adress <-> normalised_name 
		LIMIT 30  ;
		*/
		
/*
DROP TABLE IF EXISTS test_geocoding_coulisse ; 
CREATE TABLE test_geocoding_coulisse AS
SELECT gid, (postal_normalize(adresse))[1], source, fuzzy_date, f.*
FROM test_extension.test_sample_adress
	, historical_geocoding.geocode_name(
	query_adress:= (postal_normalize(adresse))[1]
	, query_date:= fuzzy_date
	, target_scale_range := numrange(0,30)
	, ordering_priority_function := '100 * semantic + 5 * temporal  + 0.01 * scale + 0.001 * spatial '
		, semantic_distance_range := numrange(0.5,1)	
		, temporal_distance_range:= sfti_makesfti(1820,1820,2000,2000)
		, scale_distance_range := numrange(0,30) 
		, optional_reference_geometry := NULL-- ST_Buffer(ST_GeomFromText('POINT(652208.7 6861682.4)',2154),5)
		, optional_spatial_distance_range := NULL -- numrange(0,10000)
		) AS  f 
WHERE source = 'ras';  
*/
	
-------------------------------------
-------------------------------------
--- Creating tests env -------------
-------------------------------------
/*
	-- creating schema, setting path
	CREATE SCHEMA IF NOT EXISTS test_extension;  
	SET search_path to test_extension, historical_geocoding, public; 

	-- creating a table with example of test query
	DROP TABLE IF EXISTS example_adress_query ; 
	CREATE TABLE example_adress_query (
	gid serial primary key
	, adress_date_query text
	, adress_query text
	, date_query text
	);

	-- import real sample data  : 
	DROP TABLE IF EXISTS input_csv ; 
	CREATE  TABLE input_csv(
	date_b text
	, adresse text
	, source text
	); 
	-- copying the data from the file to thet table. Files are in CSV format

	COPY input_csv (date_b, adresse)
	FROM 
		'/media/sf_RemiCura/DATA/Donnees_belleepoque/sample_adresse_date_from_coulisse.csv'
	WITH (FORMAT CSV, DELIMITER ';', ENCODING  'LATIN1');

	COPY input_csv (date_b, adresse)
	FROM 
		'/media/sf_RemiCura/DATA/Donnees_belleepoque/sample_adresse_date_from_ras.csv'
	WITH (FORMAT CSV, DELIMITER ';', ENCODING  'LATIN1');

	WITH to_be_updated AS (
		SELECT date_b, adresse, 'ras' as source
		FROM input_csv
		WHERE char_length(date_b) > 5
		UNION ALL 
		SELECT date_b, adresse, 'coulisse'
		FROM input_csv
		WHERE char_length(date_b) <= 5
	)
	UPDATE input_csv AS i SET  source =  tbu.source 
	FROM to_be_updated AS tbu 
	WHERE i.date_b = tbu.date_b AND i.adresse = tbu.adresse   ; 

	DROP TABLE IF EXISTS test_extension.test_sample_adress ; 
	CREATE TABLE test_extension.test_sample_adress(
		gid serial primary key
		,date_b text
		, adresse text
		, source text
		, fuzzy_date sfti
	) ;
	INSERT INTO test_extension.test_sample_adress (date_b, adresse, source, fuzzy_date) 
	SELECT date_b, adresse, source, sfti_makesfti((date_b::date-'1 year'::interval)::date, date_b::date, date_b::date,(date_b::date+'1 year'::interval)::date )
	FROM input_csv
	WHERE date_b ILIKE '__/__/____'
	UNION ALL 
	SELECT date_b, adresse, source, sfti_makesfti(date_b::int-1,date_b::int,date_b::int, date_b::int+1 )
	FROM input_csv
	WHERE date_b ILIKE '____' ;
	
	SELECT *
	FROM test_sample.
	SELECT *
	FROM input_csv
	
	INSERT INTO example_adress_query (adress_query,date_query )
		SELECT adresse, date_b 
		FROM input_csv;

	DROP TABLE input_csv ; 

	SELECT *
	FROM example_adress_query; 

	INSERT INTO example_adress_query (adress_query,date_query) VALUES
		('10b r. Chauchat, Paris', 'entre 1820 et 1828')
		, ('10b r. Chauchat, Paris', '1820  1828')
		, ('10b r. Chauchat, Paris', '1820-1828')
		, ('10b r. Chauchat, Paris', '01/02/1820-03/04/1828')
		, ('10b r. Chauchat, Paris', NULL);
 




-------- 1.1 : Normalise ------------
	---------- 1.1.1 separate adress and date			 --------
		WITH input_test AS (
			SELECT '24, rue du Quatre-Septembre;1912' AS q UNION ALL 
			SELECT '24, rue du Quatre-Septembre, 1912' UNION ALL 
			SELECT '24, rue du Quatre-Septembre _ 1912' UNION ALL 
			SELECT '24, rue du Quatre-Septembre, PARIS, 1912 ;' UNION ALL
			SELECT '24, rue du Quatre-Septembre' 
		 )
		SELECT r.*
		FROM input_test
			, historical_geocoding.separate_adress_and_date(q) as r ; 
			
	---------- 1.1.2 Parse and normalise adress and date	 --------
	---------- 1.1.2.1 parse/normalise adress			 --------
		WITH input_test AS (
			SELECT '24, rue du Quatre-Septembre ' AS q UNION ALL 
			SELECT '24, rue du Quatre-Septembre ' UNION ALL 
			SELECT '24, rue du Quatre-Septembre ' UNION ALL 
			SELECT 'rue du Quatre-Septembre, PARIS  ' UNION ALL
			SELECT '24b, rue du Quatre-Septembre' 
		 )
		 SELECT f.*
		FROM  input_test 
			, historical_geocoding.normalise_parse_adress(q, 'PARIS'::text) as f ; 

			
	---------- 1.1.2.2 parse/normalise date 				 --------
		WITH input_test AS (
			SELECT '1897'::text AS q 
			-- UNION ALL  SELECT '4 mai 1895 ' 
			-- UNION ALL  SELECT '01/02/1987 ' 
			-- UNION ALL  SELECT 'entre le 2 mai 1834 et le 6 Juin 1854'
			-- UNION ALL  SELECT '(01/02/1852,06/07/1854,08/09/1859,10/10/1865)' 
		 )  
		SELECT f.*
		FROM input_test, historical_geocoding.normalise_date(q ) AS f; 

		
	
	---------- 1.1.2.3 parse/normalise numbering			 --------

		WITH input_test AS (
			SELECT '12b' AS q 
			 UNION ALL  SELECT '12 ante' 
			 UNION ALL  SELECT '12 ter' 
			 UNION ALL  SELECT '12' 
		 )   
		SELECT f.*
		FROM  input_test,
			historical_geocoding.normalise_numbering(q ) AS f  ; 

-------- 1.2 : Match ------------
	---------- 1.2.3 match numering 					 --------
	---------- 1.2.1 match street /city name 				 --------
	---------- 1.2.2 match date 						 --------
	
*/