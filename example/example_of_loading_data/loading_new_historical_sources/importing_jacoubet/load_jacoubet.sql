--------------------------------
-- Rémi Cura, 2016
-- projet geohistorical data
-- 
--------------------------------
-- import et normalisation du plan de Paris de Jacoubet de Benoit
-- 
--------------------------------
  -- CREATE EXTENSION IF NOT EXISTS postal ; 
  -- CREATE EXTENSION IF NOT EXISTS postgis ; 	
  CREATE SCHEMA IF NOT EXISTS jacoubet_paris ; 
  SET search_path to jacoubet_paris, historical_geocoding, geohistorical_object, public; 

-- import data into database
  
  --load jacoubet road axis data with  shp2pgsql
    -- /usr/lib/postgresql/9.5/bin/shp2pgsql -d -I /media/sf_RemiCura/DATA/Donnees_belleepoque/pour_serveur/jacoubet_l93_utf8.shp jacoubet_paris.jacoubet_src_axis | psql -d test_geocodage;

  -- load jacoubet building  number
	-- /usr/lib/postgresql/9.5/bin/shp2pgsql -d -I /media/sf_RemiCura/DATA/Donnees_belleepoque/pour_serveur/vasserot_adresses_alpage_bis.shp jacoubet_paris.jacoubet_src_number | psql -d test_geocodage ;

  -- load jacoubet planche, that is the estimated time interval for each par tof the jacoubet map
	-- /usr/lib/postgresql/9.5/bin/shp2pgsql -d -I /media/sf_RemiCura/DATA/Donnees_belleepoque/pour_serveur/jacoubet_planche.shp jacoubet_paris.jacoubet_src_planche_l93 | psql -d test_geocodage;

ALTER TABLE jacoubet_paris.jacoubet_src_axis ALTER COLUMN geom TYPE geometry(multilinestring,2154) USING ST_Multi(ST_SetSRID(geom,2154)); 
ALTER TABLE jacoubet_paris.jacoubet_src_number ALTER COLUMN geom TYPE geometry(multipoint,2154) USING ST_Multi(ST_SetSRID(geom,2154)); 
ALTER TABLE jacoubet_paris.jacoubet_src_planche_l93 ALTER COLUMN geom TYPE geometry(multipolygon,2154) USING ST_Multi(ST_SetSRID(geom,2154)); 
	
SELECT *
FROM geohistorical_object.historical_source ;

-- add relevant entry into geohistorical_object schema : `historical_source` and `numerical_origin_process`


		INSERT INTO geohistorical_object.historical_source VALUES 
			('jacoubet_paris'
			, 'Atlas Général de la Ville, des faubourgs et des monuments de Paris, Simon-Théodore Jacoubet'
			, 'Simon-Théodore Jacoubet, né en 1798 à Toulouse fut architecte employé dès
		1823 à la Préfecture de la Seine puis chef du bureau chargé de la réalisation des
		plans d’alignements. Mêlé à divers procès liés à ses activités à la préfecture, il fut
		révolutionnaire en 1830, 1832 puis 1848, arrêté, interné et condamné à la déportation
		en Algérie en 1852, condamné à la mort civile et enfin assigné à résidence à
		Montesquieu-Volvestre la même année. Il sera l’auteur du plus grand et plus complet
		plan de Paris existant sur la première moitié du XIXe siècle.
		La réalisation de son Atlas Général de la Ville, des faubourgs et des monuments
		de Paris est une fenêtre ouverte non seulement sur la topographie parisienne préhaussmanienne,
		mais aussi sur le fonctionnement des services de voirie de la Seine.
		13. En 1851 encore, les plans de percements de la rue de Rivoli entre la rue de la Bibliothèque et la rue
		du Louvre seront tracés sur un plan parcellaire très proche de celui de Vasserot 
		...'
		, sfti_makesfti(1825, 1827, 1836, 1837)
		,  '{"default": 4, "road_axis":2.5, "building":1, "number":2}'::json 
		) ; 


		INSERT INTO geohistorical_object.numerical_origin_process VALUES
		('jacoubet_paris_axis'
			, 'The axis were manually created by people from geohistorical data project, using the georeferenced scan as background'
			, 'details on data : rules of creation, validation process, known limitations, etc. '
			, sfti_makesfti(2007, 2007, 2016, 2016)  -- date of data creation
			, '{"default": 1, "road_axis":3, "building":0.5, "number":1.5}'::json) --precision
		, ('jacoubet_paris_number'
			, 'number of Jacoubet, taken from Vasserot, and hand corrected with the Jacoubet background by Maurizio'
			, 'details on data : rules of creation, validation process, known limitations, etc. '
			, sfti_makesfti(2012, 2012, 2016, 2016)  -- date of data creation
			, '{"default": 1, "road_axis":3, "building":0.5, "number":1.5, "number_semantic":0.9}'::json) --precision

		, ('jacoubet_paris_quartier'
			, 'quartier of jacoubet, reconstructed from number of Jacoubet, taken from Vasserot, and hand corrected with the Jacoubet background by Maurizio, '
			, 'Each number had a quartier information. We corrected this information to eliminate error of typing most likely, and created a quartier geometry usign a buffer(buffer(geom,300),-290), ie conceptually an alpha shape'
			, sfti_makesfti('17/10/2016'::date, '17/10/2016'::date, '18/10/2016'::date, '18/10/2016'::date)  -- date of data creation
			, '{"default": 1, "quartier":300}'::json) --precision
	 


-- ### Create new tables inheriting from `historical_geocoding` ###
	SELECT *
	FROM jacoubet_src_number
	LIMIT 100  ;
	
	DROP TABLE IF EXISTS jacoubet_axis ; 
	CREATE TABLE jacoubet_axis(
		gid serial primary key
	) INHERITS (rough_localisation) ; 

	DROP TABLE IF EXISTS jacoubet_quartier ; 
	CREATE TABLE jacoubet_quartier( 
	) INHERITS (rough_localisation) ; 

	DROP TABLE IF EXISTS jacoubet_number ; 
	CREATE TABLE jacoubet_number(
		gid serial primary key
		, id_num_sca text
		, id_parc text
		, quartier text 
	) INHERITS (precise_localisation) ; 

	DROP TABLE IF EXISTS jacoubet_relations ;
	CREATE TABLE jacoubet_alias (
	) INHERITS (geohistorical_relation) ;

-- register this new tables
	 SELECT geohistorical_object.register_geohistorical_object_table(  'jacoubet_paris', 'jacoubet_axis'::text)
		, geohistorical_object.register_geohistorical_object_table(  'jacoubet_paris', 'jacoubet_quartier'::text)
		, geohistorical_object.register_geohistorical_object_table(  'jacoubet_paris', 'jacoubet_number'::text)
		, geohistorical_object.register_geohistorical_object_table(  'jacoubet_paris', 'jacoubet_relations'::text) ;

--index whats necessary
	-- creating indexes 
-- 	CREATE INDEX ON jacoubet_axis USING GIN (normalised_name gin_trgm_ops) ;  
-- 	CREATE INDEX ON jacoubet_axis USING GIST(geom) ;
-- 	CREATE INDEX ON jacoubet_axis USING GIST(CAST (specific_fuzzy_date AS geometry)) ;
-- 	CREATE INDEX ON jacoubet_axis (historical_source) ;
-- 	CREATE INDEX ON jacoubet_axis (numerical_origin_process) ;

-- 	CREATE INDEX ON jacoubet_quartier USING GIN (normalised_name gin_trgm_ops) ;  
-- 	CREATE INDEX ON jacoubet_quartier USING GIST(geom) ;
-- 	CREATE INDEX ON jacoubet_quartier USING GIST(CAST (specific_fuzzy_date AS geometry)) ;
-- 	CREATE INDEX ON jacoubet_quartier (historical_source) ;
-- 	CREATE INDEX ON jacoubet_quartier (numerical_origin_process) ;

	
-- 	CREATE INDEX ON jacoubet_number USING GIN (normalised_name gin_trgm_ops) ;  
-- 	CREATE INDEX ON jacoubet_number USING GIST(geom) ;
-- 	CREATE INDEX ON jacoubet_number USING GIST(CAST (specific_fuzzy_date AS geometry)) ;
-- 	CREATE INDEX ON jacoubet_number (historical_source) ;
-- 	CREATE INDEX ON jacoubet_number (numerical_origin_process) ; 
	CREATE INDEX ON jacoubet_number USING GIN (associated_normalised_rough_name gin_trgm_ops) ; 

	CREATE INDEX ON jacoubet_number (quartier) ; 

-- 	CREATE INDEX ON jacoubet_alias USING GIN (short_historical_source_name_1 gin_trgm_ops) ;
-- 	CREATE INDEX ON jacoubet_alias USING GIN (short_historical_source_name_2 gin_trgm_ops) ; 

-- feeding the axis from jacoubet_src_axis to jacoubet_axis
		-- geom is already in lambert 93
		 
			SELECT DISTINCT ST_SRID(geom)
			FROM jacoubet_src_axis ;

			SELECT ST_Isvalid(geom)
			FROM jacoubet_src_axis
			WHERE ST_Isvalid(geom) IS FALSE ; 

			SELECT ST_AsText(geom)
			FROM jacoubet_src_axis
			LIMIT 1 ; 

		-- checking that there is no duplicates in axis: duplicates are road axis that share over 80% of their space with another axis
			WITH buffered_geom AS ( 
			SELECT gid, ST_Buffer(geom,2) as ng 
			FROM jacoubet_src_axis 
			)
			SELECT *
			FROM buffered_geom AS bg1, buffered_geom AS bg2
			WHERE bg1.gid > bg2.gid 
				AND ST_area(ST_Intersection(bg1.ng,bg2.ng))/ ST_Area(ST_Union(bg1.ng,bg2.ng)) > 0.8
				AND ST_Intersects(bg1.ng,bg2.ng) ;

				
		-- checking data consistency for road name
			--lots  of potential inconsistencies

		DROP TABLE IF EXISTS jacoubet_src_axis_ambiguity ;
		CREATE TABLE jacoubet_src_axis_ambiguity AS 
		WITH road_name AS ( -- creating a list of distinct names, agglomerating the geom for each distinct name
			SELECT   row_number() over(order by nom_entier) as id, nom_entier, count(*) AS c
				, ST_Union(geom) as geom
			FROM jacoubet_src_axis
			WHERE nom_entier is not null
			GROUP BY nom_entier
			ORDER BY nom_entier  ASC  
		)
		SELECT row_number() over() as qgis_id, rn1.id AS id1, rn1.nom_entier AS nom1, rn1.c AS count1
				, rn2.id AS id2, rn2.nom_entier AS nom2 , rn2.c AS count2
				, sim, spatial_dist::int
				, ST_Multi(ST_Union(ARRAY[ST_Buffer(rn1.geom,3), ST_Buffer(rn2.geom,3), ST_Buffer(ST_shortestline(rn1.geom,rn2.geom),1)]))::geometry(multipolygon,2154)
					as geom
				, true::boolean is_this_a_problem
		FROM road_name AS rn1
			, road_name as rn2
			,  similarity(rn1.nom_entier, rn2.nom_entier) as sim -- similarity in a semantic way
			, st_distance(rn1.geom, rn2.geom) AS spatial_dist --distance in a spatial way
			WHERE rn1.id  > rn2.id
				AND sim > 0.7
				AND spatial_dist < 500
		ORDER BY sim ASC ; 
		ALTER TABLE jacoubet_src_axis_ambiguity ADD PRIMARY KEY (qgis_id) ; 

		SELECT *
		FROM jacoubet_src_axis_ambiguity ; 

		--inserting into geocoding table :
		-- CREATE EXTENSION IF NOT EXISTS unaccent;
		--	TRUNCATE jacoubet_axis
 
		TRUNCATE jacoubet_axis ;
		INSERT INTO jacoubet_axis
		SELECT nom_entier AS historical_name
			, nom_entier || ', Paris'
			,geom AS geom
			,NULL AS specific_fuzzy_date
			,NULL AS specific_spatial_precision 
			, 'jacoubet_paris' AS historical_source
			, 'jacoubet_paris_axis' AS numerical_origin_process
			, gid AS gid
		FROM jacoubet_src_axis ;  

		SELECT normalised_name, count(*)
		FROM jacoubet_axis
		GROUP BY normalised_name
		ORDER BY normalised_name
		LIMIT 100 ; 
		-- precising temporal precision using the precise estimated time planche by planche by Bertrand. 

		WITH to_be_updated AS (
			SELECT DISTINCT ON (ja.gid)  ja.*, sfti_makesfti((min_date-1)::int, (min_date)::int, (max_date)::int, (max_date+1)::int) as new_sfti
			FROM jacoubet_axis AS ja, ST_Buffer(ja.geom,5) AS ng, jacoubet_src_planche_l93 AS jp
			WHERE ST_Intersects(ja.geom, jp.geom) = TRUE
				ORDER BY ja.gid, ST_area(ST_Intersection( ng, jp.geom))/ ST_Area(ST_Union( ng, jp.geom)) DESC
			)
			UPDATE jacoubet_axis AS ja 
				SET specific_fuzzy_date  = new_sfti 
				FROM to_be_updated AS tbu
				WHERE ja.gid = tbu.gid ;  


-- feeding the number from jacoubet

	--checking potential errors in each number 'quartier' attribute
		SELECT *
		FROM spatial_ref_sys
		WHERe srtext ILIKE '%Lambert I Carto%'
		AND auth_name ILIKE 'IGNF' ; 

	 

	UPDATE jacoubet_src_number SET quartier =  $$Chaussée d'Antin$$ WHERE quartier = $$Chausse d'Antin$$ ;
	UPDATE jacoubet_src_number SET quartier =  $$Banque de France$$ WHERE quartier = $$Bbanque de France$$; 
	UPDATE jacoubet_src_number SET quartier =  $$Cite$$ WHERE quartier = $$cIT2$$; 
	UPDATE jacoubet_src_number SET quartier =  $$Faubourg Montmartre$$ WHERE quartier ILIKE $$Fuabourg Montmartre$$; 
	UPDATE jacoubet_src_number SET quartier =  $$Invalides$$ WHERE quartier ILIKE $$Invalildes$$; 
	UPDATE jacoubet_src_number SET quartier =  $$Palais-Royal$$ WHERE quartier ILIKE $$Palai-Royal$$; 
	UPDATE jacoubet_src_number SET quartier =  $$Faubourg Poissonniere$$ WHERE quartier ILIKE $$Fauubourg Poissonniere$$; 

		
	DROP TABLE IF EXISTS jacoubet_src_number_quartier_error;
	CREATE TABLE IF NOT EXISTS jacoubet_src_number_quartier_error AS  
		WITH agglomerating_quartier_1 AS (
			SELECT cq, ST_Buffer( ST_Union(ST_Buffer(geom,500)),-470) AS agg_geom, count(*) as nb_members
				, count(*) as c 
			FROM jacoubet_src_number, CAST (quartier AS text) AS cq --clean_text(quartier) AS cq
			WHERE quartier is not null
			GROUP BY cq
			ORDER BY cq ASC, c DESC
		)
		 , agglomerating_quartier AS (
			SELECT DISTINCT ON (clean_text(cq)) *
			FROM agglomerating_quartier_1
			ORDER BY  clean_text(cq), c DESC
		)
		SELECT row_number() over() as qgis_id, cq AS cleaned_quartier, nb_members, ST_Area(agg_geom) AS quartier_area 
			, ST_SetSRID(ST_Multi(agg_geom),932007)::geometry(multipolygon,932007) AS geom 
		FROM agglomerating_quartier ;  
		ALTER TABLE jacoubet_src_number_quartier_error ADD PRIMARY KEY (qgis_id) ; 

	SELECT *
	FROM jacoubet_src_number_quartier_error 
	ORDER BY cleaned_quartier; 

	SELECT distinct ST_geometryType(geom)
	FROM jacoubet_axis ;
 
	--inserting quartier in rough_localisation
		--SELECT max(gid) FROM jacoubet_axis ; 
		--ALTER SEQUENCE jacoubet_paris.jacoubet_axis_gid_seq INCREMENT BY 4266 ; 
	TRUNCATE jacoubet_quartier ;
	INSERT INTO jacoubet_quartier(historical_name, normalised_name, geom, specific_fuzzy_date, specific_spatial_precision, historical_source, numerical_origin_process)
		SELECT
			cleaned_quartier AS historical_name
			,'quartier '|| cleaned_quartier || ', Paris'AS normalised_name
			,ST_Transform(geom , 2154) AS geom
			,NULL AS specific_fuzzy_date
			,NULL AS specific_spatial_precision 
			, 'jacoubet_paris' AS historical_source
			, 'jacoubet_paris_quartier' AS numerical_origin_process  
	FROM jacoubet_src_number_quartier_error ; 

	-- UPDATE jacoubet_quartier SET specific_spatial_precision = (ST_MinimumBoundingRadius(geom)).radius ;  

	-- checking potential errors in nom_entier (road_name)
	SELECT  ct, count(*)
	FROM jacoubet_src_axis, clean_text(nom_entier) as ct
	GROUP BY ct
	ORDER BY ct; 

	SELECT *
	FROM jacoubet_src_number
	LIMIT 1  ; 

	DROP TABLE IF EXISTS jacoubet_src_number_ambiguity ;
		CREATE TABLE jacoubet_src_number_ambiguity AS 
		WITH road_name AS ( -- creating a list of distinct names, agglomerating the geom for each distinct name
			SELECT   row_number() over(order by nom_entier) as id, nom_entier, count(*) AS c
				, ST_Union(geom) as geom
			FROM jacoubet_src_number
			WHERE nom_entier is not null
			GROUP BY nom_entier
			ORDER BY nom_entier  ASC  
		)
		SELECT row_number() over() as qgis_id, rn1.id AS id1, rn1.nom_entier AS nom1, rn1.c AS count1
				, rn2.id AS id2, rn2.nom_entier AS nom2 , rn2.c AS count2
				, sim, spatial_dist::int
				, ST_SetSRID(ST_Multi(ST_Union(ARRAY[ST_Buffer(rn1.geom,3), ST_Buffer(rn2.geom,3), ST_Buffer(ST_shortestline(rn1.geom,rn2.geom),1)])),2154)::geometry(multipolygon,2154)
					as geom
				, true::boolean is_this_a_problem
		FROM road_name AS rn1
			, road_name as rn2
			,  similarity(rn1.nom_entier, rn2.nom_entier) as sim -- similarity in a semantic way
			, st_distance(rn1.geom, rn2.geom) AS spatial_dist --distance in a spatial way
			WHERE rn1.id  > rn2.id
				AND sim > 0.7
				AND spatial_dist < 500
		ORDER BY sim ASC ; 
		ALTER TABLE jacoubet_src_number_ambiguity ADD PRIMARY KEY (qgis_id) ; 

		SELECT *
		FROM jacoubet_src_number_ambiguity 
		WHERE nom1 NOT ILIKE '%Neuve%' AND nom2 NOT ILIKE '%Neuve%' 
		ORDER BY sim DESC , spatial_dist desc; 

		

	--inserting number 
	SELECT count(*)
	FROM jacoubet_src_number
	LIMIT 1 ; 

	SELECT *
	FROM jacoubet_number
	LIMIT 1 ; 


	
	INSERT INTO jacoubet_number (historical_name, normalised_name, geom, specific_fuzzy_date, specific_spatial_precision, historical_source, numerical_origin_process, associated_normalised_rough_name, id_num_sca, id_parc, quartier)
		SELECT full_name AS historical_name
			, full_name || ', Paris'   AS normalised_name
			,ST_Transform(ST_SetSRID(geom, 932007) , 2154) AS geom
			,NULL AS specific_fuzzy_date
			,NULL AS specific_spatial_precision 
			, 'jacoubet_paris' AS historical_source
			, 'jacoubet_paris_number' AS numerical_origin_process
			, clean_text(full_name)
			,   id_num_sca, id_parc, quartier
		FROM  
			(SELECT CASE WHEN num_voies != '0' AND num_voies IS NOT NULL THEN num_voies ||' '||nom_entier ELSE nom_entier END AS full_name
				, nom_entier
				, id_num_sca, id_parc, quartier
				, geom
			FROM jacoubet_src_number)
			AS cleaned_name  ;

	SELECT *
	FROM jacoubet_number
	LIMIT 100 ; 
		