--------------------------------
-- Rémi Cura, 2016
-- projet geohistorical data
-- 
--------------------------------
-- import et normalisation des communes selon cassini, retraité par l'EHESS et le projet geopeuple
--------------------------------

    CREATE SCHEMA IF NOT EXISTS cassini_commune_france;
  -- onc hange le path psql pour ne pas avoir à repeter le schema 
    SET search_path to cassini_commune_france, historical_geocoding, geohistorical_object, public; 


--charger les données dans la base avec shp2pgsql
    -- /usr/lib/postgresql/9.5/bin/shp2pgsql -d -I /media/sf_RemiCura/DATA/Donnees_belleepoque/bertrand/history_communes.shp cassini_commune_france.cassini_commune_src  > /tmp/tmp_cas.sql ;
    --  psql -d geocodage_historique -f /tmp/tmp_cas.sql ;
	ALTER TABLE cassini_commune_src ALTER COLUMN geom TYPE geometry(multipolygon,2154) USING ST_SetSRID(geom,2154)  ; 
	
   
   SELECT *
   FROM cassini_commune_src as cas
   WHERE cas.start IS NULL
   LIMIT 100

	

 -- adding relevant entry in geohistorical_object tables 

 INSERT INTO  geohistorical_object.historical_source  VALUES
			('cassini_communes_france'
				, 'Emprise des communes de FRance depuis 1789 jusqu a 2016, extrait des cartes cassini et d autre source par l EHESS et le projet geopeuple'
				, 'Extrait de la base de donnée de 10/2016 fourni par Bertrand. Cette source de donnée n est pas parfaite, en particulier, on ne sait pas vraimetn quels sont les documents historiques utilises'
			, sfti_makesfti('1792-01-01'::date, '1793-01-01'::date, '2015-01-01'::date, '2016-01-01'::date)
			,  '{"default": 100, "town":100}'::json 
			) ; 
			
INSERT INTO geohistorical_object.numerical_origin_process VALUES
			('communes_france_from_cassini_and_others'
				, 'this are town limit extracted from cassini map and various other data. We don t have precision on the process'
				, 'we d ont now a lot about the process. Most likely manual. May have start from current insee data'
				, sfti_makesfti(2002, 2003, 2016, 2016)  -- date of data creation
				, '{"default": 100, "town":100}'::json ) ; 



-- creating new table for town
	DROP TABLE IF EXISTS cassini_town CASCADE; 
	CREATE TABLE cassini_town(
		gid serial primary key REFERENCES cassini_commune_src(gid)
	) INHERITS (rough_localisation) ;  
	TRUNCATE cassini_town CASCADE ; 

	SELECT geohistorical_object.register_geohistorical_object_table('cassini_commune_france','cassini_town'::regclass); 
	--SELECT enable_disable_geohistorical_object(  'cassini_commune_france', 'cassini_town'::regclass, true)	  ; 

-- 	CREATE INDEX ON cassini_town USING GIN (normalised_name gin_trgm_ops) ;  
-- 	CREATE INDEX ON cassini_town USING GIST(geom) ;
-- 	CREATE INDEX ON cassini_town USING GIST(CAST (specific_fuzzy_date AS geometry)) ;
-- 	CREATE INDEX ON cassini_town (historical_source) ;
-- 	CREATE INDEX ON cassini_town (numerical_origin_process) ; 

--inserting the town limit from source

	INSERT INTO cassini_town 
		SELECT nom AS historical_name
				,'commune '|| geohistorical_object.clean_text(nom)   AS normalised_name
				,  ST_SNapToGrid(ST_SImplifyPreserveTopology(geom,50),1) AS geom
				,CASE WHEN cas.start IS NULL THEN NULL ELSE 
					sfti_makesfti((cas.start::date-'1 year'::interval)::date, cas.start::date, (COALESCE(cas.end, '2016-01-01'))::date,  (COALESCE((cas.end+'1 year'::interval)::date, '2016-06-01'))::date ) 
					END AS specific_fuzzy_date
				,NULL AS specific_spatial_precision 
				, 'cassini_communes_france' AS historical_source
				, 'communes_france_from_cassini_and_others' AS numerical_origin_process
				, gid
		FROM cassini_commune_src as cas ; 
 

	UPDATE cassini_town SET specific_spatial_precision = (ST_MinimumBoundingRadius(geom)).radius ; 

	
	SELECT  nom, code_insee, cas.start, cas.end, geom  
   FROM cassini_commune_src as cas
   LIMIT 1  ; 

   SELECT *
   FROM cassini_town
   LIMIT 100 ;  

   SELECT distinct historical_source, numerical_origin_process
   FROM rough_localisation  ; 
