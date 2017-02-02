
DROP TABLE IF EXISTS public.export_all_paris_road_name2 ; 
CREATE TABLE IF NOT EXISTS public.export_all_paris_road_name2  AS 
SELECT  DISTINCT ON (cname) woparis AS road_name
FROM historical_geocoding.rough_localisation 
	,  geohistorical_object.clean_text(normalised_name) AS cname
	, regexp_replace( normalised_name, ', paris', '', 'i') AS woparis
WHERE normalised_name ILIKE '%PARIS'
AND numerical_origin_process NOT ILIKE 'jacoubet_paris_quartier'
AND cname NOT ILIKE '%acces %' ;


SELECT *
FROM export_all_paris_road_name2
	, regexp_replace( normalised_name, ', paris', '', 'i') AS woparis
WHERE woparis ILIKE '%PARIS%'
ORDER BY normalised_name ASC
LIMIT 100;


SELECT *
FROM export_all_paris_road_name2
LIMIT 100;
