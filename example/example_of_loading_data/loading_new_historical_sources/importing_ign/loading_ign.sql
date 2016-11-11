--------------------------------
-- Rémi Cura, 2016
-- projet geohistorical data
-- 
--------------------------------
-- import and normalise of current data
-- BDAdress for adress number, BDTopo for street name
--------------------------------

	CREATE SCHEMA IF NOT EXISTS ign_paris;
	SET search_path to ign_paris, historical_geocoding, geohistorical_object, public; 


-- importing the two files
	-- /usr/lib/postgresql/9.5/bin/shp2pgsql -d -I /media/sf_RemiCura/DATA/Donnees_belleepoque/pour_serveur/adresse.shp ign_paris.ign_bdadresse_src | psql -d test_geocodage ;

	-- /usr/lib/postgresql/9.5/bin/shp2pgsql -d -I /media/sf_RemiCura/DATA/Donnees_belleepoque/pour_serveur/troncon_de_route_bdadresse.shp ign_paris.ign_bdadresse_axis_src | psql -d test_geocodage;

	-- /usr/lib/postgresql/9.5/bin/shp2pgsql -d -W "LATIN1" -I /media/sf_RemiCura/DATA/Donnees_belleepoque/pour_serveur/COMMUNE.SHP ign_paris.ign_commune_src | psql -d test_geocodage ;
	
	ALTER TABLE ign_bdadresse_src ALTER COLUMN geom TYPE geometry(point,2154) USING ST_SetSRID(geom,2154)  ; 
	ALTER TABLE ign_bdadresse_axis_src ALTER COLUMN geom TYPE geometry(MultilinestringZ,2154) USING ST_SetSRID(ST_Force3D(geom),2154)  ; 
	ALTER TABLE ign_commune_src  ALTER COLUMN geom TYPE geometry(Multipolygon,2154) USING ST_SetSRID( geom, 2154)  ; 

	-- loading the list of shortenign used in road name :
	DROP TABLE IF EXISTS ign_bdtopo_abbreviations ; 
	CREATE TABLE IF NOT EXISTS ign_bdtopo_abbreviations(
		nom_complet text PRIMARY KEY
		, abbreviation text
	); 
	COPY ign_bdtopo_abbreviations FROM '/media/sf_RemiCura/DATA/Donnees_belleepoque/pour_serveur/abbreviation_nom_rue.csv' DELIMITER ';' CSV HEADER;

	DROP TABLE IF EXISTS laposte_commune_code_postal ; 
	CREATE TABLE laposte_commune_code_postal (
	gid serial primary key, 
	code_commune_INSEE text  ,
	nom_commune text,
	code_postal text 
	); 
	COPY laposte_commune_code_postal (code_commune_INSEE, nom_commune, code_postal ) FROM '/media/sf_RemiCura/DATA/Donnees_belleepoque/pour_serveur/laposte_correspondance_code_postal_nom_commune.csv' DELIMITER ';' CSV HEADER;
	CREATE INDEX ON laposte_commune_code_postal USING GIN (nom_commune gin_trgm_ops) ; 
	CREATE INDEX ON laposte_commune_code_postal (code_postal) ; 
	SELECT *
	FROM laposte_commune_code_postal
	LIMIT 100 ; 

	SELECT *
	FROM ign_bdtopo_abbreviations ; 
 
	
	SELECT *
	FROM ign_bdadresse_src
	LIMIT 1  ; 

	SELECT * 
	FROM ign_bdadresse_axis_src
	LIMIT 1  ; 

	SELECT *
	FROM ign_commune_src
	LIMIT 1  ; 

	-- the import is too large, we need to remove the road and number that are not within paris:
		 
		--remove road axis that are not in paris 
		--remove number that are not in paris

/*
		DELETE FROM  ign_bdadresse_axis_src
		WHERE code_posta NOT ILIKE '75%'  ; 

		DELETE FROM  ign_bdadresse_src
		WHERE code_posta NOT ILIKE '75%'  ; 
*/

-- add relevant entry into geohistorical_object schema : `historical_source` and `numerical_origin_process`

 
		-- DELETE FROM  geohistorical_object.historical_source   WHERE short_name ILIKE '%ign_paris%' ; 
		INSERT INTO  geohistorical_object.historical_source  VALUES
		('ign_paris'
			, 'Produit BDAdresse et BDtopo fourni par l IGN, extrait de 2016 par l interface web'
			, 'La BDtopo fourni des axes relativement fiables sur toute la france, les numérotations sont en revanche souvent placé automatiquement, d ou un manque de qualité parfois. Les numéros sont à l adresse'
		, sfti_makesfti(2006,2007, 2012,2013)
		,  '{"default": 1, "road_axis":1, "building":1, "number":4}'::json 
		) ; 

		INSERT INTO  geohistorical_object.historical_source  VALUES
		('ign_commune_geofla'
			, 'Produit par l IGN, ,recupere sur le site en 2013'
			, 'ce fichier fourni les limites officiel des communes, et une correspondance avec leur code postal, cela dit l orthographe des communes est problematique, car les noms ont été posttraité'
		, sfti_makesfti(2006,2007, 2012,2013)
		,  '{"default": 30, "town":30}'::json 
		) ; 
	 
		INSERT INTO geohistorical_object.numerical_origin_process VALUES
		('ign_paris_axis'
			, 'les axes de la bdtopo sont fait par mise à jour et photo interpretation. La precision 3D est plus faible que la précision plani'
			, 'Export web de la bdtopo en 2016, sur la plateforme pour les adresses (tous les champs de la bdtopo ne sont pas là) '
			, sfti_makesfti(2010, 2010, 2016, 2016)  -- date of data creation
			, '{"default": 2, "road_axis":2}'::json  ) 
		,
		('ign_paris_number'
			, 'Les numerotations de la BDAdresse export 2016 sont générés automatiquement par interpolations linéaire, puis corrigés pour etre placé à la plaqsue la plupart du temps. '
			, 'Les numérotations ne sont pas toujours extremement fiables, il s agit d une export par le web de 2016'
			, sfti_makesfti(2010, 2010, 2016, 2016)  -- date of data creation
			, '{"default": 1, "road_axis":3, "building":0.5, "number":1.5}'::json) --precision

		, 
		('ign_france_town'
			, 'limite des communes avec des noms posttraite un peu dur à lire, ainsi que code postal '
			, 'il s agit dun export web de 2013'
			, sfti_makesfti(2012, 2012, 2013, 2013)  -- date of data creation
			,  '{"default": 30, "town":30}'::json 
			)
		 ; 
 
 
-- creating the geocoding tables : 
	DROP TABLE IF EXISTS ign_paris_axis CASCADE; 
	CREATE TABLE ign_paris_axis(
		gid serial  REFERENCES ign_bdadresse_axis_src(gid)
		, clef_bdtopo text  
	) INHERITS (rough_localisation) ;  
	TRUNCATE ign_paris_axis CASCADE ; 

	DROP TABLE IF EXISTS ign_france_town CASCADE; 
	CREATE TABLE ign_france_town(
		gid serial primary key REFERENCES ign_commune_src(gid) 
	) INHERITS (rough_localisation) ;  
	TRUNCATE ign_france_town CASCADE ; 

	DROP TABLE IF EXISTS ign_paris_number ; 
	CREATE TABLE ign_paris_number(
		gid serial primary key  REFERENCES ign_bdadresse_src(gid) 
		, clef_bdtopo text --REFERENCES ign_paris_axis(clef_bdtopo ) 
	) INHERITS (precise_localisation) ; 
	TRUNCATE ign_paris_number CASCADE ; 
	

	DROP TABLE IF EXISTS ign_paris_relation ;
	CREATE TABLE ign_paris_relation (
	) INHERITS (geohistorical_relation) ;

 
	-- register this new tables  
	SELECT geohistorical_object.register_geohistorical_object_table(  'ign_paris', 'ign_paris_axis'::text)	 
		, geohistorical_object.register_geohistorical_object_table(  'ign_paris', 'ign_france_town'::text)	 
		, geohistorical_object.register_geohistorical_object_table(  'ign_paris', 'ign_paris_number'::text)
		, geohistorical_object.register_geohistorical_object_table(  'ign_paris', 'ign_paris_relation'::text) ;



		--  SELECT enable_disable_geohistorical_object(  'ign_paris', 'ign_paris_axis'::regclass, true)	 
-- 			, enable_disable_geohistorical_object(  'ign_paris', 'ign_france_town'::regclass, true)	 
-- 			, enable_disable_geohistorical_object(  'ign_paris', 'ign_paris_number'::regclass, true)
-- 			, enable_disable_geohistorical_object(  'ign_paris', 'ign_paris_relation'::regclass, true) ;

	--index whats necessary
		-- creating indexes 
-- 		CREATE INDEX ON ign_paris_axis USING GIN (normalised_name gin_trgm_ops) ;  
-- 		CREATE INDEX ON ign_paris_axis USING GIST(geom) ;
-- 		CREATE INDEX ON ign_paris_axis USING GIST(CAST (specific_fuzzy_date AS geometry)) ;
-- 		CREATE INDEX ON ign_paris_axis (historical_source) ;
-- 		CREATE INDEX ON ign_paris_axis (numerical_origin_process) ; 
		CREATE INDEX ON ign_paris_axis (clef_bdtopo) ; 

-- 		CREATE INDEX ON ign_france_town USING GIN (normalised_name gin_trgm_ops) ;  
-- 		CREATE INDEX ON ign_france_town USING GIST(geom) ;
-- 		CREATE INDEX ON ign_france_town USING GIST(CAST (specific_fuzzy_date AS geometry)) ;
-- 		CREATE INDEX ON ign_france_town (historical_source) ;
-- 		CREATE INDEX ON ign_france_town (numerical_origin_process) ;  
 

		
-- 		CREATE INDEX ON ign_paris_number USING GIN (normalised_name gin_trgm_ops) ;  
-- 		CREATE INDEX ON ign_paris_number USING GIST(geom) ;
-- 		CREATE INDEX ON ign_paris_number USING GIST(CAST (specific_fuzzy_date AS geometry)) ;
-- 		CREATE INDEX ON ign_paris_number (historical_source) ;
-- 		CREATE INDEX ON ign_paris_number (numerical_origin_process) ; 
		CREATE INDEX ON ign_paris_number USING GIN (associated_normalised_rough_name gin_trgm_ops) ; 
		CREATE INDEX ON ign_paris_number (clef_bdtopo) ; 
 

-- 		CREATE INDEX ON ign_paris_relation USING GIN (short_historical_source_name_1 gin_trgm_ops) ;
-- 		CREATE INDEX ON ign_paris_relation USING GIN (short_historical_source_name_2 gin_trgm_ops) ; 

-- filling the town table : 
	SELECT historical_name, normalised_name, geom, specific_fuzzy_date, specific_spatial_precision, historical_source, numerical_origin_process, gid
	FROM ign_france_town
	LIMIT 1  ; 

	TRUNCATE ign_france_town ; 
	INSERT INTO ign_france_town
		SELECT nom_com
			, 'commune '|| clean_text(replace(nom_com, '-', ' ')) 
			, ST_SnapToGrid(ST_SimplifyPreserveTopology(geom,50),1)
			, NULL
			, NULL
			, 'ign_commune_geofla'
			,'ign_france_town'
			,gid
	 FROM ign_commune_src  ;  

	 
	--UPDATE ign_france_town SET specific_spatial_precision = (ST_MinimumBoundingRadius(geom)).radius ;
	 

-- preparing to fill the axis table
	--first road name contain shortening, which is annoying for normalised name
	--<e ened to remove these

	SELECT *
	FROM ign_bdadresse_axis_src
	WHERE nom_rue_dr IS NOT NULL
	LIMIT 10 ; 

	
	WITH first_word AS (
		SELECT fw ,nom_rue_dr 
		FROM ign_bdadresse_axis_src
			, substring(nom_rue_dr, '^(\w+)\s.*?$')as fw
		WHERE nom_rue_dr = nom_rue_ga
			AND char_length(fw) <= 3
	)
	SELECT fw, count(*) AS c, min(nom_rue_dr)
	FROM first_word
	GROUP BY  fw
	ORDER BY fw; 

	-- translation of abbreviation is in 'ign_bdtopo_abbreviations'
	SELECT *
	FROM ign_bdtopo_abbreviations ; 

	-- insert axis (if different name on left and right, insert it 2 times)

	TRUNCATE ign_paris_axis  CASCADE;
	INSERT INTO ign_paris_axis (historical_name, normalised_name, geom, specific_fuzzy_date, specific_spatial_precision, historical_source, numerical_origin_process, gid, clef_bdtopo ) 
		SELECT 
			nom_rue_dr
			, clean_text(nom_rue_dr) ||', ' || nom_commune
			,geom
			, sfti_makesfti((daterec::date - '1 year'::interval)::date,daterec::date, '2015/01/01'::date,'2016/06/01'::date)--daterec
			, NULL::float
			, 'ign_paris'
			, 'ign_paris_axis'
			, gid 
			,cleabs  
		FROM (
			SELECT DISTINCT ON (src.gid, la.gid ) nom_rue_dr, geom, daterec, src.gid, cleabs, la.nom_commune
			FROM ign_bdadresse_axis_src AS src
				LEFT OUTER JOIN laposte_commune_code_postal AS la ON (src.code_posta = la.code_postal)
			WHERE (nom_rue_dr ILIKE nom_rue_ga
			OR nom_rue_dr IS NULL OR nom_rue_ga IS  NULL
			)  
		UNION ALL   --because road name on left and on right side may not be the same, we duplicate the road that have several name
			SELECT DISTINCT ON (src.gid, la.gid) nom_rue_dr, geom, daterec, src.gid, cleabs, la.nom_commune
			FROM   ign_bdadresse_axis_src as src
				LEFT OUTER JOIN laposte_commune_code_postal AS la ON (src.code_posta = la.code_postal)
			WHERE nom_rue_dr NOT ILIKE  nom_rue_ga
				AND src.code_posta ILIKE la.code_postal
		UNION ALL 
			SELECT DISTINCT ON (src.gid, la.gid) nom_rue_ga AS nom_rue_dr, geom, daterec, src.gid, cleabs, la.nom_commune
			FROM   ign_bdadresse_axis_src AS src
				LEFT OUTER JOIN laposte_commune_code_postal AS la ON (src.code_posta = la.code_postal)
			WHERE nom_rue_dr NOT ILIKE nom_rue_ga 
				AND src.code_posta ILIKE la.code_postal
		) AS sub  ;
 
	--now we need to correct the inserted axis so they dont use the sshortening in normalised_name
	WITH potential_abbr AS (
		SELECT  fw , count(*) AS c, max(normalised_name) as ex
		FROM ign_paris_axis
			, substring(normalised_name, '^(\w+)\s.*?$')as fw
		WHERE normalised_name is not null
			AND char_length(fw) <= 3
		GROUP BY fw
		ORDER BY fw asc
	)
	SELECT * --nom_complet
	FROM potential_abbr AS pa
		LEFT OUTER JOIN ign_bdtopo_abbreviations AS ig ON (pa.fw ILIKE ig.abbreviation) 
	LIMIT 100 ; 


	-- replacing the shortening in the adresses
	WITH to_be_updated_1 AS (
		SELECT  pa.historical_name, pa.gid, pa.geom, normalised_name, fw, abbreviation, nom_complet , postfix
		FROM ign_paris_axis AS pa
			, substring(normalised_name, '^\w+(\s.*?)$') as postfix   
			, substring(normalised_name, '^(\w+)\s.*?$')as fw
			,LATERAL ( SELECT DISTINCT ON(abbreviation ) ign_bdtopo_abbreviations.* FROM  ign_bdtopo_abbreviations WHERE  fw ILIKE  abbreviation ORDER BY abbreviation, char_length(nom_complet) ASC) AS ig
		WHERE normalised_name is not null AND fw IS NOT NULL 
			AND char_length(fw) <= 4
			AND nom_complet IS NOT NULL 
	)  
	UPDATE ign_paris_axis AS pa SET normalised_name =  cv.nom_complet || postfix 
	FROM to_be_updated_1 AS cv
	WHERE pa.gid = cv.gid AND pa.geom = cv.geom; 
	

	--41905
	SELECT *
	FROM ign_paris_axis
	WHERE normalised_name is not null
	LIMIT 1000 ; 



-- preparing to fill the number table
	--number references roads with some shortening in it, which is annoying
	
	SELECT *
	FROM ign_bdadresse_src AS num 
		 LEFT OUTER JOIN ign_paris_axis AS ax ON(num.lien_objet = ax.clef_bdtopo ) 
	 WHERE ax.gid IS NULL
	LIMIT 1  ;

	TRUNCATE ign_paris_number ;
	INSERT INTO ign_paris_number (historical_name, normalised_name, geom, specific_fuzzy_date, specific_spatial_precision, historical_source, numerical_origin_process, gid, clef_bdtopo ) 
		SELECT DISTINCT ON (ad.gid)  
			numero || ' ' || ad.nom_voie
			,numero || ' ' || COALESCE( ax.normalised_name , ad.nom_voie)  
			, ad.geom
			, CASE WHEN daterec IS NULL THEN NULL ELSE  sfti_makesfti((daterec::date - '1 year'::interval)::date,daterec::date, '2015/01/01'::date,'2016/06/01'::date)END
			, NULL
			, 'ign_paris'
			, 'ign_paris_number'
			, ad.gid
			, ad.lien_objet  
		FROM ign_bdadresse_src AS ad
			LEFT OUTER JOIN laposte_commune_code_postal AS la ON (ad.code_posta = la.code_postal)
			, ign_paris_axis AS ax 
		WHERE ad.lien_objet = ax.clef_bdtopo  ;  
			--AND ax.normalised_name IS NOT NULL ; 


	SELECT *
	FROM ign_paris_number  
	LIMIT 100; 
 
 