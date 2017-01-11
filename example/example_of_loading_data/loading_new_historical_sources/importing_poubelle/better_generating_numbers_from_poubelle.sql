----------------------------------------------
-- Remi Cura , projet Belle Epoque, 2017
----------------------------------------------

-- reconstructing road from raod segments 

SET SEARCH_PATH to poubelle_paris, historical_geocoding, geohistorical_object, public ; 

SELECT *
FROM  poubelle_paris.poubelle_axis
LIMIT 1 ;


-- grouop by semantic
-- for each group, decompose into points, group points by similarity, look fo single points.
--starting froma  single point, create the chain one segment by one segment.



-- test of native postgis functions

SELECT St_AsText(ST_Linemerge(geom))
FROM CAST('MULTILINESTRING((0 0, 10 10),(30 30, 19 19),(10 10, 20 20))' AS geometry) as geom


SELECT *
FROM spatial_ref_sys
WHERE srtext ILIKE '%lamb93%'
LIMIT 1 

SELECT *
FROM poubelle_topo_cleaned 
LIMIT 1 ; 

DROP TABLE IF EXISTS poubelle_grouped_by_semantic ; 
CREATE TABLE IF NOT EXISTS poubelle_grouped_by_semantic  AS 
WITH reconstitued_axis AS (
	SELECT row_number() over() as id, normalised_name 
		, ST_Transform(
			ST_Multi(
			ST_LineMerge(
			ST_Multi( 
				ST_CollectionExtract(
					ST_Collect(ST_Transform(geom,932011))
					, 2)
			)
			)
				) , 2154)
			 as ag_geom
		, count(*) as c
	FROM poubelle_paris.poubelle_axis 
	GROUP BY normalised_name   
)
SELECT row_number() over() AS gid,normalised_name, g.geom
FROM reconstitued_axis, ST_Dump(ag_geom) AS g ; 

--HAVING count(*) >= 3;

SELECT st_astext(ag_geom)
FROM poubelle_grouped_by_semantic
LIMIT 1000

SELECT ST_NumGeometries(ag_geom), count(*) as c2
FROM poubelle_grouped_by_semantic
WHERE c > 1
GROUP BY ST_NumGeometries(ag_geom)
ORDER BY c2 DESC ; 


SELECT *
FROM poubelle_paris.poubelle_axis_approx_width
LIMIT 100 ; 


SELECT *
FROM poubelle_paris.poubelle_src_merged
WHERE (adr_fg88 IS NOT NULL OR adr_dg88 IS NOT NULL )AND (adr_fg88 IS NOT NULL OR adr_dg88 IS NOT NULL )


DROP TABLE IF EXISTS poubelle_left_point_add  ;
CREATE TABLE IF NOT EXISTS poubelle_left_point_add  AS
SELECT gid, nom_1888, adr_dg88 AS adr_g
FROM poubelle_paris.poubelle_src_merged
WHERE 
LIMIT 1 


-- generatign all number that have been edited in the data : that is that are not null, 0 or -1.
DROP TABLE IF EXISTS base_numbers ; 
CREATE TABLE base_numbers  AS 

WITH all_sides AS (
	SELECT pa.gid,  pa.geom road_axis, approx_road_width , adr_dg88 start_number , adr_fg88 end_number,true AS is_left_side, nom_1888, normalised_name, historical_name
	FROM poubelle_axis AS pa
		LEFT OUTER JOIN poubelle_src_merged AS pb USING (gid )
		LEFT OUTER JOIN poubelle_axis_approx_width AS pw USING(gid)
	UNION ALL 
	SELECT  pa.gid, pa.geom road_axis, approx_road_width , adr_dd88 start_number , adr_fd88 end_number, false AS is_left_side, nom_1888, normalised_name, historical_name
	FROM poubelle_axis AS pa
		LEFT OUTER JOIN poubelle_src_merged AS pb USING (gid )
		LEFT OUTER JOIN poubelle_axis_approx_width AS pw USING(gid)
)
SELECT *
FROM all_sides WHERE gid = 62
, starting_points AS (
	SELECT  gid AS seg_id, ST_LineInterpolatePoint(ST_GeometryN(road_axis,1),0.001) AS number_point, 0.001 AS perc_curv_abs, sn AS numb, is_left_side::int
	FROM  all_sides AS al
		, historical_geocoding.numerotation2float(start_number  ) AS sn
		, historical_geocoding.numerotation2float(end_number) AS en 
	WHERE   sn >0  
)
, end_point AS (
	SELECT gid AS seg_id, ST_LineInterpolatePoint(ST_GeometryN(road_axis,1),0.999) AS number_point, 0.999 AS perc_curv_abs,en AS numb, is_left_side::int
	FROM  all_sides AS al
		, historical_geocoding.numerotation2float(start_number  ) AS sn
		, historical_geocoding.numerotation2float(end_number) AS en 
	WHERE   en >0  
)
SELECT row_number() over() as num_id, *
FROM (
SELECT  *
FROM starting_points
UNION ALL 
SELECT *
FROM end_point
) AS sub ; 
ALTER TABLE base_numbers ADD PRIMARY KEY (num_id) ;
CREATE INDEX  ON base_numbers USING GIST (number_point) ; 

SELECT *
FROM base_numbers
WHERE seg_id = 62
ORDER BY seg_id, is_left_side, numb
LIMIT 1000 ; 

-- projecting the number on the streets to find which street does not have enough information
	--for each street, get the first and last point , check that there is a number left and right not far from this point and that this point is correctly within the axis

WITH candidate_axis AS (
	(SELECT DISTINCT ON (p.gid, bn1.num_id, bn2.num_id) p.gid, bn1.numb AS sn, bn2.numb AS en, bn1.is_left_side, p.geom AS axis_geom
	FROM poubelle_grouped_by_semantic As p
		, base_numbers AS bn1
		, base_numbers AS bn2
	WHERE normalised_name is not null
		AND ST_DWithin(p.geom, bn1.number_point, 0.00001)
		AND ST_DWIthin(ST_StartPoint(p.geom), bn1.number_point, 10) = TRUE
		AND bn1.is_left_side::boolean = TRUE
		AND ST_DWithin(p.geom, bn2.number_point, 0.00001)
		AND ST_DWIthin(ST_EndPoint(p.geom), bn2.number_point, 10) = TRUE
		AND bn2.is_left_side::boolean = TRUE
	ORDER BY p.gid, bn1.num_id, bn2.num_id, ST_Distance(ST_StartPoint(p.geom), bn1.number_point) , ST_Distance(ST_EndPoint(p.geom), bn2.number_point))
	UNION ALL 
	(SELECT DISTINCT ON (p.gid, bn1.num_id, bn2.num_id) p.gid, bn1.numb AS sn, bn2.numb AS en, bn1.is_left_side, p.geom AS axis_geom
	FROM poubelle_grouped_by_semantic As p
		, base_numbers AS bn1
		, base_numbers AS bn2
	WHERE normalised_name is not null
		AND ST_DWithin(p.geom, bn1.number_point, 0.00001)
		AND ST_DWIthin(ST_StartPoint(p.geom), bn1.number_point, 10) = TRUE
		AND bn1.is_left_side::boolean = FALSE
		AND ST_DWithin(p.geom, bn2.number_point, 0.00001)
		AND ST_DWIthin(ST_EndPoint(p.geom), bn2.number_point, 10) = TRUE
		AND bn2.is_left_side::boolean = FALSE
	ORDER BY p.gid, bn1.num_id, bn2.num_id, ST_Distance(ST_StartPoint(p.geom), bn1.number_point) , ST_Distance(ST_EndPoint(p.geom), bn2.number_point))
)
SELECT * 
FROM candidate_axis
WHERE abs(sn -en ) >=2 ; 


	SELECT *
	FROM poubelle_grouped_by_semantic As p
	WHERE normalised_name is not null
		AND ((EXISTS (
			SELECT 1 
			FROM base_numbers AS bn
			WHERE ST_DWithin(p.geom, bn.number_point, 0.00001)
				AND ST_DWIthin(ST_StartPoint(p.geom), bn.number_point, 10) = TRUE
				AND is_left_side::boolean = TRUE
		)
		AND EXISTS (
			SELECT 1 
			FROM base_numbers AS bn
			WHERE ST_DWithin(p.geom, bn.number_point, 0.00001)
				AND ST_DWIthin(ST_EndPoint(p.geom), bn.number_point, 10) = TRUE
				AND is_left_side::boolean = TRUE
		)
		)
		AND (
		 EXISTS (
			SELECT 1 
			FROM base_numbers AS bn
			WHERE ST_DWithin(p.geom, bn.number_point, 0.00001)
				AND ST_DWIthin(ST_StartPoint(p.geom), bn.number_point, 10) = TRUE
				AND is_left_side::boolean = false
		)
		AND EXISTS (
			SELECT 1 
			FROM base_numbers AS bn
			WHERE ST_DWithin(p.geom, bn.number_point, 0.00001)
				AND ST_DWIthin(ST_EndPoint(p.geom), bn.number_point, 10) = TRUE
				AND is_left_side::boolean = false		)
		)) ;



-- for each axis, for each side , 
	-- get all numbers possible
	-- order number by curvabs
	-- for each successive pair
		-- extract a substring corresponding to the curvabs
		-- find the width of this segment bylooking for something similar in poubelle_axis_approx_width
		-- generate the numbers usign the dedicated function
		-- keep trace of semantic stuff


	DROP TABLE IF EXISTS generating_number ; 
	CREATE TABLE IF NOT EXISTS generating_number  AS
-- 	DROP TABLE IF EXISTS temp_test; 
-- 	CREATE TABLE IF NOT EXISTS temp_test  AS
-- 	DROP TABLE IF EXISTS temp_test_0; 
-- 	CREATE TABLE IF NOT EXISTS temp_test_0  AS
	WITH number_per_axis AS (
		SELECT  DISTINCT ON (p.gid, bn1.num_id )  p.gid AS axis_id, bn1.numb AS numb , bn1.is_left_side, number_point,  p.geom AS axis_geom
			, ST_LineLocatePoint( p.geom, number_point) AS pt_curv_abs, normalised_name
		FROM poubelle_grouped_by_semantic As p
			, base_numbers AS bn1 
		WHERE p.normalised_name is not null
			AND ST_DWithin(p.geom, bn1.number_point, 0.00001) 
		ORDER BY p.gid, bn1.num_id, ST_Distance(p.geom,bn1.number_point),  ST_Distance(ST_Centroid(p.geom),bn1.number_point)
		--LIMIT 2000
		)
	, removing_duplicate_numbers AS (
		SELECT DISTINCT ON (axis_id, is_left_side, numb) row_number() over() as tid, *
		FROM number_per_axis
		ORDER BY axis_id, is_left_side, numb, pt_curv_abs
	)
	, generating_segment_candidates AS (
		SELECT  tid, axis_id, normalised_name, is_left_side
			,numb,  lag(numb, 1, NULL) OVER(PARTITION BY axis_id, is_left_side ORDER BY numb ASC  ) AS numb_prev
			,rc_LineSubstring(axis_geom, lag(pt_curv_abs, 1, NULL) OVER(PARTITION BY axis_id, is_left_side ORDER BY numb ASC  ), pt_curv_abs   ) AS substr
			, pt_curv_abs
			, lag(pt_curv_abs, 1, NULL) OVER(PARTITION BY axis_id, is_left_side ORDER BY numb ASC  )
		FROM removing_duplicate_numbers 
		ORDER BY numb ASC
		
	)
	 , getting_road_width AS ( --and fixing is_left_side to take into account the rc_line_substring possible switch
		-- crossing with poubelle_paris.poubelle_axis_approx_width to transfer width
		SELECT DISTINCT ON (gs.tid)  tid, axis_id, normalised_name, is_left_side::boolean, CASE WHEN numb< numb_prev THEN  true ELSE false END AS number_is_reversed
			, numb , numb_prev ,substr, pa.approx_road_width
			, ST_LineLocatePoint(gs.substr, ST_StartPoint(ST_GeometryN(pa.geom,1))) > ST_LineLocatePoint(gs.substr, ST_EndPoint(ST_GeometryN(pa.geom,1))) AS axis_is_reversed
		FROM generating_segment_candidates AS gs
			, poubelle_paris.poubelle_axis_approx_width AS pa
			WHERE 
				numb_prev is not null AND 
				ST_DWithin(gs.substr, pa.geom,10) = TRUE
			ORDER BY gs.tid , ST_Area(ST_Intersection(ST_Buffer(gs.substr,10), ST_Buffer(pa.geom,10))) DESC
	)
	, generating_numbers AS (
		SELECT gr.* , f.*
		FROM getting_road_width AS gr 
			, poubelle_paris.generate_numbers_points(
					CASE WHEN axis_is_reversed IS TRUE THEN   ST_Reverse(substr)   ELSE substr  END
					, approx_road_width 
					, is_left_side  
					,CASE WHEN axis_is_reversed IS TRUE THEN numb ELSE numb_prev END
					,CASE WHEN axis_is_reversed IS TRUE THEN numb_prev ELSE numb END
					, 2.0::float --  sidewalk_width
					,COALESCE(approx_road_width*1.2,10)   --,10.0::float 
					) AS f 
		--WHERE ST_Length(substr) > 15
	)
	SELECT row_number() over() as tid2, axis_id, normalised_name
		, numbers_value 
		, is_left_side, approx_road_width
		, number_geom::geometry(point,2154)
	FROM generating_numbers ; 

	ALTER TABLE generating_number ADD PRIMARY KEY (tid2);  
	CREATE INDEX ON generating_number USING GIST(number_geom) ;  

	--removing duplicates points 
	-- find duplicated points : point not too far, same semantic, same number.

	DROP TABLE IF EXISTS generated_points_to_be_deleted ; 
	CREATE TABLE IF NOT EXISTS generated_points_to_be_deleted  AS 
	WITH duplicates  AS (
	SELECT DISTINCT ON (gn1.tid2) gn1.tid2 AS tid2_1, gn2.tid2 AS tid2_2
		, gn1.number_geom 
		, gn1.normalised_name
		, gn1.numbers_value 
	FROM generating_number AS gn1 , generating_number AS gn2 
	WHERE 
		gn1.tid2 != gn2.tid2
		AND ST_DWIthin(gn1.number_geom,gn2.number_geom,50) = TRUE
		AND gn1.normalised_name ILIKE gn2.normalised_name
		AND gn1.numbers_value = gn2.numbers_value
	ORDER BY gn1.tid2  
	)
	, closest_point AS (
		SELECT DISTINCT ON (d.tid2_1) d.*, sdist
		FROM duplicates As d 
			, generating_number AS gn1
			,  ST_Distance(d.number_geom,gn1.number_geom) as sdist
			WHERE ST_DWIthin(d.number_geom,gn1.number_geom,50) = TRUE
				AND d.tid2_1 != gn1.tid2
			ORDER BY d.tid2_1, sdist ASC
	)
	SELECT DISTINCT ON (numbers_value, normalised_name) tid2_1, normalised_name, numbers_value, number_geom::geometry(point,2154)
	FROM closest_point
	ORDER BY numbers_value, normalised_name, sdist ASC ; 

	DELETE FROM generating_number AS gn1 WHERE EXISTS (SELECT 1 FROM generated_points_to_be_deleted AS gp WHERE gn1.tid2 =gp.tid2_1 ) ;


DROP TABLE IF EXISTS poubelle_number_for_export  ;
CREATE TABLE IF NOT EXISTS poubelle_number_for_export AS  
 SELECT DISTINCT ON (tid2) row_number() over() AS gid, gn.normalised_name, gn.numbers_value, gn.is_left_side, round(gn.approx_road_width::numeric,2)
	, ST_SNapToGrid(gn.number_geom,0.1)::geometry(point,2154) AS number_geom
	,NULL::text AS quartier -- quar.normalised_name AS quartier
 FROM generating_number AS gn ; 
	-- , jacoubet_paris.jacoubet_quartier AS quar
	-- WHERE ST_Intersects(gn.number_geom, quar.geom)
	--ORDER BY tid2, ST_Distance(gn.number_geom, quar.geom), ST_Area(quar.geom) DESC
 
WITH to_be_updated as (
	SELECT DISTINCT ON (gid ) gid, quar.normalised_name AS quartier
	FROM poubelle_number_for_export AS gn
		, jacoubet_paris.jacoubet_quartier AS quar
	 WHERE ST_Intersects(gn.number_geom, quar.geom)
	 ORDER BY gid, ST_Distance(gn.number_geom, quar.geom), ST_Area(quar.geom) DESC
)
UPDATE poubelle_number_for_export AS pn SET quartier = tbu.quartier
FROM to_be_updated AS tbu 
WHERE tbu.gid  = pn.gid ; 
					
   
	CREATE OR REPLACE FUNCTION rc_LineSubstring(geom geometry, abs1 float, abs2 float) RETURNS geometry
		AS $$ --Thin wrapper around regular postgis function
		DECLARE 
		BEGIN
			 IF abs2<abs1 THEN
				RETURN ST_Reverse(ST_LineSubstring(geom, abs2,abs1) ); 
			ELSE
				RETURN ST_LineSubstring(geom, abs1,abs2) ; 
			 END IF ;  
		END;
$$ LANGUAGE plpgsql;