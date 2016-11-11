--------------------------------
-- Rémi Cura, 2016
-- projet geohistorical data
-- 
--------------------------------
-- import and normalise of current data
-- from APUR : on Paris neighboorhood
--------------------------------



	CREATE SCHEMA IF NOT EXISTS apur_paris;
	SET search_path to apur_paris, historical_geocoding, geohistorical_object, public; 

-- YOU NEED TO IMPORT IGNF SPATIAL REF SYS
-- you can find https://github.com/Remi-C/IGN_spatial_ref_for_PostGIS/Put_IGN_SRS_into_Postgis.sql


-- importing the APUR sHape file
	-- /usr/lib/postgresql/9.5/bin/shp2pgsql -d -I /media/sf_RemiCura/DATA/Donnees_belleepoque/pour_serveur/Quartiers_apur.shp apur_paris.apur_quartier_paris_src | psql -d test_geocodage ;
	ALTER TABLE apur_quartier_paris_src ALTER COLUMN GEOM TYPE geometry(multipolygon,2154) USING ST_Transform(ST_SetSRID(geom,932001),2154) ; 

	SELECT *
	FROM apur_quartier_paris_src ;


-- adding the relevant information in geohistorical_object : 
	INSERT INTO  geohistorical_object.historical_source  VALUES
			('apur_paris_quartier'
				, 'fichier de l Agence Parisienne de L Urbanisme decrivant les quartiers de Paris, recupere chez Maurizio'
				, ' Pas de detail sur ces donnees, les qualites sont donc à prendre avec des pincettes'
			, sfti_makesfti(2000, 2001, 2009, 2010)
			,  '{"default":1, "quartier":100}'::json 
			) ; 

			INSERT INTO geohistorical_object.numerical_origin_process VALUES
			('apur_paris_quartier_process'
				, 'fichier de l Agence Parisienne de L Urbanisme decrivant les quartiers de Paris, recupere chez Maurizio, processus de production inconnu'
				, 'processus de production inconnu '
				, sfti_makesfti(2000, 2001, 2009, 2010)
				,  '{"default":1, "quartier":100}'::json 
			) ;

-- creating tables
	
	DROP TABLE IF EXISTS apur_paris_quartier CASCADE; 
	CREATE TABLE apur_paris_quartier(
		gid serial primary key REFERENCES apur_quartier_paris_src(gid)
	) INHERITS (rough_localisation) ;  
	TRUNCATE apur_paris_quartier CASCADE ; 

	-- register this new tables
		SELECT geohistorical_object.register_geohistorical_object_table('apur_paris', 'apur_paris_quartier'::regclass) ; 
		-- SELECT enable_disable_geohistorical_object('apur_paris', 'apur_paris_quartier'::regclass, true) ; 


-- 		 CREATE INDEX ON apur_paris_quartier USING GIN (normalised_name gin_trgm_ops) ;  
-- 		CREATE INDEX ON apur_paris_quartier USING GIST(geom) ;
-- 		CREATE INDEX ON apur_paris_quartier USING GIST(CAST (specific_fuzzy_date AS geometry)) ;
-- 		CREATE INDEX ON apur_paris_quartier (historical_source) ;
-- 		CREATE INDEX ON apur_paris_quartier (numerical_origin_process) ; 

	-- inserting into this table
	TRUNCATE apur_paris_quartier ; 
	INSERT INTO apur_paris_quartier
	SELECT  
		l_qu
		, 'quartier '|| clean_text(l_qu) || ' , Paris' 
		,geom
		, NULL
		, NULL
		,'apur_paris_quartier'
		,'apur_paris_quartier_process'
		,gid 
	FROM apur_quartier_paris_src ; 

		SELECT DISTINCT historical_source, numerical_origin_process
		FROM rough_localisation ; 

		