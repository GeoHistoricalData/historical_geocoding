------------------------
-- Remi Cura, 2016 , Projet Belle Epoque
------------------------

-- Util : creating a new fuzzy type 
-- based on trapezoid fuzzy date
-- from extension 'pgsfti'
-- with casting for ease of use

	CREATE EXTENSION IF NOT EXISTS pgsfti ; 
	CREATE EXTENSION IF NOT EXISTS postgis ; 



-- sfti handling :

-- this new functions is handy to break a sfti into a record (nammed values)
DROP FUNCTION IF EXISTS sfti2record(   IN i_sfti sfti, OUT sa FLOAT,OUT ca FLOAT,OUT cb FLOAT,OUT sb FLOAT,OUT l FLOAT); 
CREATE OR REPLACE FUNCTION sfti2record(   IN i_sfti sfti, OUT sa FLOAT,OUT ca FLOAT,OUT cb FLOAT,OUT sb FLOAT,OUT l FLOAT) AS 
	$BODY$
		--@brief : this function takes a sfti and returns a record 
		DECLARE     
		BEGIN 	
		SELECT sfti_ar[1],  sfti_ar[2],  sfti_ar[3],  sfti_ar[4],  sfti_ar[5] INTO sa,ca,cb,sb,l
		FROM CAST(i_sfti AS sfti)as f 
			, trim(both '()' from f::text) as ar
			, regexp_split_to_array(ar, ',') as sfti_ar ; 
					
			RETURN ;
				END ; 
	$BODY$
LANGUAGE plpgsql  IMMUTABLE STRICT; 



DROP FUNCTION IF EXISTS sfti2table(   IN i_sfti sfti); 
CREATE OR REPLACE FUNCTION sfti2table(   IN i_sfti sfti)
RETURNS TABLE (seq int, var text, val float) AS 
	$BODY$
		--@brief : this function takes a sfti and returns a record 
		DECLARE     
		BEGIN 
		RETURN QUERY	
		WITH arr AS (
		SELECT sfti_ar 
		FROM CAST(i_sfti AS sfti)as f 
			, trim(both '()' from f::text) as ar
			, regexp_split_to_array(ar, ',') as sfti_ar 
		)
		SELECT a::int,b::text,c::float
		FROM  arr, unnest(ARRAY[1,2,3,4,5]) WITH ORDINALITY AS t1(a, rn)
		JOIN   unnest(ARRAY['sa','ca','cb','sb','l']) WITH ORDINALITY AS t2(b, rn) USING (rn)
		JOIN unnest(sfti_ar) WITH ORDINALITY AS t3(c, rn) USING (rn)   ; 
					
		RETURN ;
		END ; 
	$BODY$
LANGUAGE plpgsql  IMMUTABLE STRICT; 


SELECT t.*
FROM sfti_makesfti(1783, 1785, 1791, 1799) as f 
	,  sfti2record(f) as r
	, sfti2table(f) as t ; 



	-- visualisation 
	DROP FUNCTION IF EXISTS sfti2geom(   IN i_sfti sfti, OUT o_geom GEOMETRY ); 
	CREATE OR REPLACE FUNCTION sfti2geom(    IN i_sfti sfti, OUT o_geom GEOMETRY   ) AS 
		$BODY$
			--@brief : this function takes a sfti and creates a polygon representing the trapezoid
			DECLARE     
				_e float := 0.0001 ; 
			BEGIN 	
				SELECT ST_MakePolygon(ST_MakeValid(ST_MakeLine(ARRAY[
					ST_MAkePoint(rec.sa-_e,0)
					,ST_MAkePoint(rec.ca,rec.l)
					,ST_MAkePoint(rec.cb,rec.l)
					,ST_MAkePoint(rec.sb+_e,0)
					, ST_MAkePoint(rec.sa-_e,0)
					]))
					) INTO o_geom
				FROM sfti2record(i_sfti) as rec ;  
		RETURN ; END ; 
		$BODY$
	LANGUAGE plpgsql IMMUTABLE STRICT; 

	SELECT ST_AsText(res), ST_AsText(res2)
	FROM sfti_fuzzify('1783-11-1'::date, '6 month'::interval) AS f
		,   sfti_makesfti(1841) AS f2
		, sfti2geom( f) as res, sfti2geom( f2) as res2  ; 
 

DROP FUNCTION IF EXISTS sfti_distance_asym(   IN i_sfti1 sfti, IN i_sfti2 sfti, INOUT bmin float  , INOUT bmax float , OUT fuzzy_distance float ); 
CREATE OR REPLACE FUNCTION sfti_distance_asym(    IN i_sfti1 sfti, IN i_sfti2 sfti, INOUT bmin float DEFAULT NULL, INOUT bmax float DEFAULT NULL, OUT fuzzy_distance float   ) AS 
	$BODY$
		--@brief : this function takes two stfi A and B and compute a fuzzy distance measure 
		DECLARE      
		BEGIN 	
			--distance from A to B (not the same as from B to A)
			-- geom_dist(A,B) + area(A) - shared_area(A,B) 
			
			SELECT ST_Distance(A,B) + ST_Area(A) - AintB
				INTO fuzzy_distance
			FROM sfti2geom(i_sfti1) AS A, sfti2geom(i_sfti2) AS B 
					, ST_Area(ST_Intersection(A,B)) AS AintB;  
			
	RETURN ; END ; 
	$BODY$
LANGUAGE plpgsql IMMUTABLE CALLED ON NULL INPUT; 



-- adding cast for ease of use 
 
 SELECT  g.*
FROM sfti_makesfti('01-06-1783'::date, '01-01-1785'::date, '01-01-1791'::date, '01-01-1799'::date) as f , sfti2record(f)  as g ; 

-- cast to geom
-- cast to date interval 
--cast to float interval
-- cast to float
--cast to int


-- cast to geom
DROP CAST IF EXISTS (sfti AS geometry(polygon,0)) ; 
CREATE CAST (sfti AS geometry(polygon,0))
    WITH FUNCTION sfti2geom(sfti) ; 
    
-- cast to date interval (range) ()	

	SELECT daterange('01/02/1859','03/04/1859') ; 

	
SELECT (make_date(floor(i_relative_date)::int,1,1) +  age(to_timestamp(ceiling(i_relative_date)*365*24*60*60), to_timestamp( i_relative_date*365*24*60*60) ))::date
FROM CAST('1859.6' AS float) AS i_relative_date ;


DROP FUNCTION IF EXISTS yearfloat2date(   IN yearfloat float,  OUT yeardate date); 
CREATE OR REPLACE FUNCTION yearfloat2date ( IN yearfloat float,  OUT yeardate date  ) AS 
	$BODY$
		--@brief : this function takes a year expressed as float (1858.35), and converts it to a proper date
		-- WARNING : we introduce sligh error, as we consider there are 365 days a year
		DECLARE       
		BEGIN
		SELECT (make_date(floor(i_relative_date)::int,1,1) +  age( to_timestamp( i_relative_date*365*24*60*60) , to_timestamp(floor(i_relative_date)*365*24*60*60)))::date INTO yeardate
			FROM CAST(yearfloat AS float) AS i_relative_date ; 
		
	RETURN ; END ; 
	$BODY$
LANGUAGE plpgsql IMMUTABLE CALLED ON NULL INPUT; 

SELECT yearfloat2date( 1860) ; 


	

DROP FUNCTION IF EXISTS sfti2daterange(   IN i_sfti1 sfti,  OUT minmax_date daterange)CASCADE ; 
CREATE OR REPLACE FUNCTION sfti2daterange(  IN i_sfti1 sfti,  OUT minmax_date daterange  ) AS 
	$BODY$
		--@brief : this function takes one sfti and convert it into a postgres daterange, by taking the lower and upper bound of sfti
		DECLARE      
		BEGIN 	 
			SELECT daterange(yearfloat2date(f.sa), yearfloat2date(f.sb)) INTO minmax_date
			FROM sfti2record(i_sfti1) as f  ;  
	RETURN ; END ; 
	$BODY$
LANGUAGE plpgsql IMMUTABLE CALLED ON NULL INPUT; 


CREATE CAST (sfti AS daterange)
    WITH FUNCTION sfti2daterange(sfti) ; 

 SELECT  sfti2daterange(f), f::daterange
FROM sfti_makesfti('01-06-1783'::date, '01-01-1785'::date, '01-01-1791'::date, '01-01-1799'::date) as f ; 


    
	
--cast to float interval

	DROP FUNCTION IF EXISTS  sfti2numrange (   IN i_sfti1 sfti,  OUT minmax_float numrange )CASCADE; 
	CREATE OR REPLACE FUNCTION sfti2numrange (   IN i_sfti1 sfti,  OUT minmax_float numrange  ) AS 
	$BODY$
		--@brief : this function takes one sfti and convert it into a postgres numrange by taking the lower and upper bound of sfti
		DECLARE      
		BEGIN 	 
			SELECT numrange(f.sa::numeric,  f.sb::numeric ) INTO minmax_float
			FROM sfti2record(i_sfti1) as f  ;  
	RETURN ; END ; 
	$BODY$
	LANGUAGE plpgsql IMMUTABLE CALLED ON NULL INPUT; 



CREATE CAST (sfti AS numrange)
    WITH FUNCTION sfti2numrange(sfti) ; 

 SELECT  sfti2numrange(f), f::numrange
FROM sfti_makesfti('01-06-1783'::date, '01-01-1785'::date, '01-01-1791'::date, '01-01-1799'::date) as f ; 


-- cast to float


	DROP FUNCTION IF EXISTS  sfti2float (   IN i_sfti1 sfti,  OUT centroid_float float)CASCADE; 
	CREATE OR REPLACE FUNCTION sfti2float (   IN i_sfti1 sfti,  OUT centroid_float float  ) AS 
	$BODY$
		--@brief : this function takes one sfti and convert it into one float
		DECLARE      
		BEGIN 	 
			SELECT ST_X(ST_Centroid(sfti2geom(i_sfti1))) INTO centroid_float
			FROM sfti2record(i_sfti1) as f  ;  
	RETURN ; END ; 
	$BODY$
	LANGUAGE plpgsql IMMUTABLE CALLED ON NULL INPUT; 


CREATE CAST (sfti AS float) WITH FUNCTION sfti2float(sfti);  
	SELECT  sfti2float(f), f::float 
FROM sfti_makesfti('01-06-1783'::date, '01-01-1785'::date, '01-01-1791'::date, '01-01-1799'::date) as f ; 

	
--cast to int

	DROP FUNCTION IF EXISTS  sfti2int (   IN i_sfti1 sfti,  OUT centroid_int int)CASCADE; 
	CREATE OR REPLACE FUNCTION sfti2int (   IN i_sfti1 sfti,  OUT centroid_int int  ) AS 
	$BODY$
		--@brief : this function takes one sfti and convert it into a postgres numrange by taking the lower and upper bound of sfti
		DECLARE      
		BEGIN 	 
			SELECT CAST(sfti2float(i_sfti1) AS int) INTO centroid_int ; 
	RETURN ; END ; 
	$BODY$
	LANGUAGE plpgsql IMMUTABLE CALLED ON NULL INPUT; 


CREATE CAST (sfti AS int) WITH FUNCTION sfti2int(sfti);  
	SELECT  sfti2int(f), f::int 
FROM sfti_makesfti('01-06-1783'::date, '01-01-1785'::date, '01-01-1791'::date, '01-01-1799'::date) as f ; 
