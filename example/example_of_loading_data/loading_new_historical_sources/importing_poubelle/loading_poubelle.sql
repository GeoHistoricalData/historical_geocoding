--------------------------------
-- Rémi Cura, 2016
-- projet geohistorical data
-- 
--------------------------------
-- import et normalisation du plan de Paris de Poubelle de Benoit
-- poubelle_TEMPORAIRE, 10/12/2014
--------------------------------

-- preparer la base de données
  --creer extensions
  -- CREATE EXTENSION IF NOT EXISTS postgis ; 

	-- le referentiel a utiliser est le lambert 93 : EPSG:2154
	SELECT *
	FROM spatial_ref_sys 
	WHERE srid = 2154 ; 
	
  --importer les srid de l'ign
  -- creer schema pour chargement des données
    CREATE SCHEMA IF NOT EXISTS poubelle_paris;
  -- onc hange le path psql pour ne pas avoir à repeter le schema 
    SET search_path to poubelle_paris, historical_geocoding, geohistorical_object, public; 

  --charger les données dans la base avec shp2pgsql
    -- /usr/lib/postgresql/9.5/bin/shp2pgsql -d -I /media/sf_RemiCura/DATA/Donnees_belleepoque/pour_serveur/poubelle_TEMPORAIRE_emprise_utf8_L93_v2.shp poubelle_paris.poubelle_src | psql -d test_geocodage;

     -- /usr/lib/postgresql/9.5/bin/shp2pgsql -d -I /media/sf_RemiCura/DATA/Donnees_belleepoque/pour_serveur/poubelle_TEMPORAIRE.shp poubelle_paris.poubelle_src_2 | psql -d test_geocodage;

	ALTER TABLE poubelle_paris.poubelle_src ALTER COLUMN geom TYPE geometry(multilinestring,2154) USING ST_SetSRID(geom,2154)  ;
	ALTER TABLE poubelle_paris.poubelle_src_2 ALTER COLUMN geom TYPE geometry(multilinestring,2154) USING ST_SetSRID(geom,2154)  ;

  -- la table poubelle_src est maintenant remplie
  -- la table poubelle_src_2 aussi : elle contient plus de données, mais moins précise. 
  -- we fuse poubelle_src and poubelle_sr_2, by taking in priority poubelle_src and completing it with poubelle_src_2 
		DROP TABLE IF EXISTS poubelle_src_merged; 
		CREATE TABLE IF NOT EXISTS  poubelle_src_merged ( LIKE poubelle_src INCLUDING DEFAULTS INCLUDING CONSTRAINTS INCLUDING INDEXES ); 

		INSERT INTO poubelle_src_merged SELECT * FROM poubelle_src ; 

		SELECT * FROM poubelle_src_2 LIMIT 1 ; 
 

		--now , creating the spatial limit of poubelle_src, adding row of poubelle_src_2 that are not withint his limit. 
		WITH fermiers_generaux AS ( 
			SELECT ST_MakePolygon(ST_ExteriorRing(ST_GeometryN(ST_Union(ST_Buffer(geom,5,'quad_segs=2')),1)) )as src_bounding
			FROM poubelle_src
			LIMIT 1 
		)
		INSERT INTO poubelle_src_merged (nom_1888, type_voie, particule, nom_voie, adr_fg88, adr_fd88, adr_dg88, adr_dd88, id, geom ) 
		SELECT nom_1888, type_voie, particule, nom_voie, adr_fg88, adr_fd88, adr_dg88, adr_dd88, id, geom 
		FROM fermiers_generaux AS fg, poubelle_src_2 AS p2
			, ST_Buffer(p2.geom,5) as ngeom
			, CAST( St_Area(ST_Intersection(fg.src_bounding,ngeom)) / ST_Area(ngeom)AS float)  as shared_surf
		WHERE shared_surf < 0.9 ;

		SELECT *
		FROM poubelle_src_merged
		LIMIT 100 ;


    --creation d'une vue pour voir les endroits problématiques
      --vue sur les rue homonymes 
        DROP VIEW IF EXISTS poubelle_compte_homonyme  ; 
        CREATE VIEW poubelle_compte_homonyme AS 
		  SELECT gid, nom_1888, count(*) over(partition by nom_1888) AS nbr_troncons, geom::geometry(multilinestring,2154)
		  FROM poubelle_src
		  ORDER BY nom_1888 ASC ;
      --vue sur les noms non rempli (NULL)    
        DROP VIEW IF EXISTS poubelle_compte_nom_null  ; 
        CREATE VIEW poubelle_compte_nom_null AS 
		SELECT gid, nom_1888, geom::geometry(multilinestring,2154)
		FROM poubelle_src
		WHERE nom_1888 IS NULL ; 

        --UTILISER historical_geocoding.numerotation2float()
  
      --vue sur les rue dont les numéros d'adresses contiennent un 0 (signe d'inconnaissance) ou un NULL (signe d'un probleme)
		SELECT *
		FROM poubelle_src , historical_geocoding.numerotation2float(adr_fg88) AS fg, historical_geocoding.numerotation2float(adr_fd88) AS fd
			, historical_geocoding.numerotation2float(adr_dg88) AS dg, historical_geocoding.numerotation2float(adr_dd88) AS dd ; 
		-- WHERE adr_fg88::int = 0 OR adr_fg88::int IS NULL OR adr_fd88::int = 0 OR adr_fd88::int IS NULL OR adr_dg88::int = 0 OR adr_dg88::int IS NULL OR adr_dd88::int = 0 OR adr_dd88::int IS NULL
      --vue verification que les numerotations gauche et droites sont bien croissantes
        SELECT *
        FROM poubelle_src 
        WHERE adr_fg88 < adr_dg88 AND adr_fd88 > adr_dd88 OR adr_fg88 > adr_dg88 AND adr_fd88 < adr_dd88
        LIMIT 10 	; 
    

	WITH tous_les_numeros AS ( 
	   SELECT gid, adr_dg88  AS numerotation FROM poubelle_src UNION ALL
	   SELECT gid, adr_dd88 FROM poubelle_src UNION ALL
	   SELECT gid, adr_fg88 FROM poubelle_src UNION ALL
	   SELECT gid, adr_fd88 FROM poubelle_src  
	  )
-- 	  SELECT  suffixe, count(*)
-- 	  FROM tous_les_numeros, historical_geocoding.normaliser_numerotation(numerotation)
-- 	  WHERE suffixe is not null
-- 	  group by suffixe
-- 	  ORDER BY suffixe ASC
	  
	  SELECT  numerotation, count(*) as n_occurence 
		, norm.*
		, historical_geocoding.numerotation2float(numerotation)
	  FROM tous_les_numeros, historical_geocoding.normaliser_numerotation(numerotation) as norm
	  GROUP BY numerotation, norm.numero, norm.suffixe
	  ORDER BY n_occurence DESC, numerotation;  


SELECT *
FROM geohistorical_object.historical_source ; 


	-- add relevant entry into geohistorical_object schema : `historical_source` and `numerical_origin_process`

  
	 
			INSERT INTO  geohistorical_object.historical_source  VALUES
			('poubelle_municipal_paris'
				, 'Atlas municipal des vingt arrondissements de la ville de Paris. 
	Dressé sous la direction de M. Alphand inspecteur général des  ponts et chaussées, par les soins de M.L Fauve, géomètre en chef, avec le concours des géomètres du plan de Paris (Alphand et Fauve, 1888) réalisé sous la direction du préfet Eugène Poubelle.'
				, 'Pour tracer ce plan, Haussmann indique dans ses mémoires (Haussmann, 1893)
	qu’une nouvelle triangulation complète de Paris a été effectuée entre 1856 et 1857,
	sous la direction d’Eugène Deschamps 18. Ainsi, ce plan constituerait la première triangulation
	complète effectuée depuis l’atlas de Verniquet, du moins si l’on conserve
	l’hypothèse d’une triangulation seulement partielle pour Jacoubet. Haussmann, affirmant
	qu’aucun grand plan de Paris n’existait lors de son arrivée à la préfecture
	renouvelle ainsi totalement les outils de l’administration. Il n’est cependant pas certain
	que les choses aient été si simples et la tendance du préfet à se placer en fondateur
	de la cartographie officielle en omettant volontairement des projets antérieurs a
	déjà été pointée par Pierre Casselle (Casselle, 2000) (C’était alors la commission des
	embellissements du Comte Siméon qui était ignorée et son rôle auprès de l’empereur
	minimisé). En effet, le frontispice d’une édition réduite au 1/10.000e conservée à la
	Bibliothèque Nationale de France (Deschamps et al., 1871) indique que le grand plan
	en 21 feuilles dressé à l’échelle de 1/5000 résume les travaux des géomètres du Plan...'
			, sfti_makesfti(1887, 1888, 1888, 1889)
			,  '{"default": 4, "road_axis":2.5, "building":1, "number":2}'::json 
			) ; 
	 

	 
			INSERT INTO geohistorical_object.numerical_origin_process VALUES
			('poubelle_paris_axis_audela_fermiers_generaux'
				, 'The axis were manually created by people from geohistorical data project, but not ufrther corrected/validated by Benoit Combes'
				, 'details on data : rules of creation, validation process, known limitations, etc. 
				the file used was provided by Benoit and named "poubelle_TEMPORAIRE.shp"
					Initially, the axis name used abbreviation : "PL" for "place", etc. The abbrebeviation were expanded to initial meaning by Rémi Cura '
				, sfti_makesfti(2007, 2007, 2016, 2016)  -- date of data creation
				, '{"default": 3, "road_axis":5, "number":4}'::json) --precision
			,
			('poubelle_paris_axis'
				, 'The axis were manually created by people from geohistorical data project, and ufrther corrected/validated by Benoit Combes for the inner part of Fermier Generaux, and not corrected for outside'
				, 'details on data : rules of creation, validation process, known limitations, etc. 
					Initially, the axis name used abbreviation : "PL" for "place", etc. The abbrebeviation were expanded to initial meaning by Rémi Cura '
				, sfti_makesfti(2007, 2007, 2016, 2016)  -- date of data creation
				, '{"default": 1, "road_axis":3, "building":0.5, "number":1.5}'::json) --precision
			, ('poubelle_paris_number'
				, 'mix of manual and automatic creation for numbers of poubelle, which are not explicitely present in the original map.'
				, 'Poubelle only contains numbers at the beginning and end of ways. mThis numbers were manually added by people from Geohistorical data project, but many are still missing.
				Therefore Rémi Cura wrote methods to complete the missing data as best as we can and generate numbers position by linear interpolation.
				The number were placed at a given distance of axis. 
				details on data : rules of creation, validation process, known limitations, etc. '
				, sfti_makesfti(2012, 2012, 2016, 2016)  -- date of data creation
				, '{"default": 1, "road_axis":3, "building":0.5, "number":1.5, "number_semantic":0.9}'::json) --precision
	 
	

--analysis of poubelle road axis name : 
	-- what kind of shortening are used in 'type_voie'
	
	SELECT type_voie, count(*) as c , max(nom_1888)
	FROM poubelle_src_merged
	GROUP BY type_voie
	ORDER BY type_voie; 

	WITH first_word AS (
		SELECT substring(nom_1888, '^(\w+)\s.*?$')as fw ,nom_1888 
		FROM poubelle_src_merged
	)
	SELECT fw, count(*) AS c, min(nom_1888)
	FROM first_word
	GROUP BY  fw
	ORDER BY fw; 

	-- creating a list of equivalent for shortening of way type
	DROP TABLE IF EXISTS poubelle_type_voie_mapping; 
	CREATE TABLE poubelle_type_voie_mapping (
	gid serial primary key
	, type_voie text
	, type_voie_full text
	) ;
	TRUNCATE poubelle_type_voie_mapping ;

	INSERT INTO poubelle_type_voie_mapping (type_voie, type_voie_full) VALUES
		('ALL','allée'),
		('AV','avenue'),
		('BD','boulevard'),
		('C', 'cité'),
		('CAR','carrefour'),
		('CHE','chemin'),
		('CHS', 'chaussée'),
		('CITE','cité'),
		('COUR','cour'),
		('CRS','cours'),
		('GAL','galerie'), 
		('HAM', 'hameau'),
		('IMP','impasse'),
		('IMPASSE','impasse'),
		('PAS','passage'),
		('PASSAGE','passage'),
		('PETIT','petit'),
		('PL','place'),
		('PLE','rue'), --note : only 1 case : PLE cafareli : upon close examination, it seems to be an error of editing : it is a 'rue'
		('PONT','pont'),
		('PORT','port'),
		('QU','quai'),
		('QUAI','quai'),
		('R','rue'),
		('RLE','ruelle'),
		('RPT','rond-point'),
		('RUE','rue'),
		('SEN', 'sentier'),
		('SQ','square'),
		('VLA','villa'),
		('VOI','voie'),
		('',''); 
	
	SELECT *
	FROM poubelle_src
	LIMIT 10 ; 

-- creating new table for axis and number
	
-- ### Create new tables inheriting from `historical_geocoding` ###
	SELECT *
	FROM poubelle_src
	LIMIT 100 ; 

	
	DROP TABLE IF EXISTS poubelle_axis CASCADE; 
	CREATE TABLE poubelle_axis(
		gid serial primary key REFERENCES poubelle_src_merged(gid)
	) INHERITS (rough_localisation) ;  
	TRUNCATE poubelle_axis CASCADE ; 

	DROP TABLE IF EXISTS poubelle_number ; 
	CREATE TABLE poubelle_number(
		gid serial primary key , 
		road_axis_id int REFERENCES poubelle_axis(gid)
	) INHERITS (precise_localisation) ; 
	TRUNCATE poubelle_number CASCADE ; 
	

	DROP TABLE IF EXISTS poubelle_relations ;
	CREATE TABLE poubelle_relations (
	) INHERITS (geohistorical_relation) ;

 
	-- register this new tables
		 SELECT geohistorical_object.register_geohistorical_object_table('poubelle_paris','poubelle_axis'::regclass)	 
			, geohistorical_object.register_geohistorical_object_table('poubelle_paris','poubelle_number'::regclass)
			, geohistorical_object.register_geohistorical_object_table('poubelle_paris','geohistorical_relation'::regclass) ;

	--index whats necessary
		-- creating indexes 
-- 		CREATE INDEX ON poubelle_axis USING GIN (normalised_name gin_trgm_ops) ;  
-- 		CREATE INDEX ON poubelle_axis USING GIST(geom) ;
-- 		CREATE INDEX ON poubelle_axis USING GIST(CAST (specific_fuzzy_date AS geometry)) ;
-- 		CREATE INDEX ON poubelle_axis (historical_source) ;
-- 		CREATE INDEX ON poubelle_axis (numerical_origin_process) ; 

		
-- 		CREATE INDEX ON poubelle_number USING GIN (normalised_name gin_trgm_ops) ;  
-- 		CREATE INDEX ON poubelle_number USING GIST(geom) ;
-- 		CREATE INDEX ON poubelle_number USING GIST(CAST (specific_fuzzy_date AS geometry)) ;
-- 		CREATE INDEX ON poubelle_number (historical_source) ;
-- 		CREATE INDEX ON poubelle_number (numerical_origin_process) ; 
		CREATE INDEX ON poubelle_number USING GIN (associated_normalised_rough_name gin_trgm_ops) ; 

		CREATE INDEX ON poubelle_number (road_axis_id) ; 

-- 		CREATE INDEX ON poubelle_alias USING GIN (short_historical_source_name_1 gin_trgm_ops) ;
-- 		CREATE INDEX ON poubelle_alias USING GIN (short_historical_source_name_2 gin_trgm_ops) ; 

-- inserting road axis: 
	-- we need to correct the nom_1888 before inserting it, using the poubelle_type_voie_mapping for that
	--first inserting 
	SELECT *
	FROM poubelle_src
	LIMIT 10 ; 

	SELECT *
	FROM poubelle_type_voie_mapping ;
	
	INSERT INTO poubelle_axis 
	SELECT nom_1888 AS historical_name
			, nom_1888 || ', Paris' AS normalised_name
			, geom AS geom
			, NULL AS specific_fuzzy_date
			, NULL AS specific_spatial_precision 
			, 'poubelle_municipal_paris' AS historical_source
			, 'poubelle_paris_axis' AS numerical_origin_process
			, gid
	FROM poubelle_src_merged   ; 

	SELECT *
	FROM poubelle_axis
	LIMIT 100 ; 

 

	-- correcting the shortening :  
	WITH corrected_value_value AS (
		SELECT gid,  normalised_name, prefix,  type_voie_full, postfix 
		FROM poubelle_axis
			, substring(normalised_name, '^\w+(\s.*?)$') as postfix  
			,  substring(normalised_name, '^(\w+)\s.*?$') as prefix 
			, LATERAL (SELECT type_voie_full FROM  poubelle_type_voie_mapping as tv WHERE tv.type_voie = upper(prefix)) as sub 
	)
	UPDATE poubelle_axis AS pa SET normalised_name =  cv.type_voie_full || postfix 
	FROM corrected_value_value AS cv
	WHERE pa.gid = cv.gid ; 

	SELECT *
	FROM poubelle_axis
	WHERE normalised_name is not null
	LIMIT 100 ; 

-- analysis of number in poubelle : 
	-- because many road are lacking the numbering information, we need to reconstruct this information
	-- first we need to re-merge the road section pertaining to a same road. 
	-- to this end, we need to find the direction of the road. In paris, the direction of a road is given regarding the Seine. 
	-- if the road is approximatively parallel to the Seine, the numbering is from uphill to downhill
	-- if the road is appromiatevily orthogonal to the Seine, the numbering is from toward the Seine to away from the Seine.
	-- we also need an approximate road width to place the numbers

	--getting approximate road width:
		--load data 
		CREATE SCHEMA IF NOT EXISTS bdtopo_x_streetgen_x_odparis ; 
		--	/usr/lib/postgresql/9.5/bin/shp2pgsql -d -I /media/sf_RemiCura/DATA/Donnees_belleepoque/pour_serveur/streetgen_recalle_tout_paris.shp bdtopo_x_streetgen_x_odparis.bdtopo_reregistered  | psql -d test_geocodage;

		SELECT *
		FROM bdtopo_x_streetgen_x_odparis.bdtopo_reregistered 
		LIMIT 10; 
 
		INSERT INTO public.spatial_ref_sys (srid,auth_name, auth_srid, srtext,proj4text) values (932011,'Remi_C',310024140,'PROJCS["Lambert 93__offseted_Paris",GEOGCS["Réseau géodésique français 1993",DATUM["Réseau géodésique français 1993",SPHEROID["IAG GRS 1980",6378137.0000,298.2572221010000,AUTHORITY["IGNF","ELG037"]],TOWGS84[0.0000,0.0000,0.0000,0,0,0,0],AUTHORITY["IGNF","REG024"]],PRIMEM["Greenwich",0.000000000,AUTHORITY["IGNF","LGO01"]],UNIT["degree",0.01745329251994330],AXIS["Longitude",EAST],AXIS["Latitude",NORTH],AUTHORITY["IGNF","RGF93G"]],PROJECTION["Lambert_Conformal_Conic_2SP",AUTHORITY["IGNF","PRC0140"]],PARAMETER["semi_major",6378137.0000],PARAMETER["semi_minor",6356752.3141],PARAMETER["latitude_of_origin",46.500000000],PARAMETER["central_meridian",3.000000000],PARAMETER["standard_parallel_1",44.000000000],PARAMETER["standard_parallel_2",49.000000000],PARAMETER["false_easting",700000.000],PARAMETER["false_northing",6600000.000],UNIT["metre",1],AXIS["Easting",EAST],AXIS["Northing",NORTH],AUTHORITY["IGNF","LAMB93"]]','+init=IGNF:LAMB93 +x_0=51000 +y_0=-240000');


		DROP TABLE IF EXISTS bdtopo_x_streetgen_x_odparis.bdtopo_reregistered_cleaned ;
		CREATE TABLE  bdtopo_x_streetgen_x_odparis.bdtopo_reregistered_cleaned(
			gid serial primary key
			,road_width float
			, geom geometry(Multilinestring,2154)
		); 
		CREATE INDEX ON bdtopo_x_streetgen_x_odparis.bdtopo_reregistered_cleaned USING GIST(geom) ; 

		INSERT INTO bdtopo_x_streetgen_x_odparis.bdtopo_reregistered_cleaned
			SELECT gid, field_3,ST_Transform( ST_SetSRID(ST_Force2D(geom),932011),2154)
			FROM bdtopo_x_streetgen_x_odparis.bdtopo_reregistered ;

		--transferring road width 
			-- TRUNCATE poubelle_axis_approx_width ; 
			DROP TABLE IF EXISTS poubelle_axis_approx_width;
			CREATE TABLE poubelle_axis_approx_width(
			gid serial REFERENCES poubelle_axis(gid)
			, geom geometry(multilinestring,2154)
			, approx_road_width float
			); 
			

			INSERT INTO poubelle_axis_approx_width
			SELECT gid, max( geom) as geom, sum(road_width * shared_surf_perc) / sum(shared_surf_perc) AS wwidth
				FROM  
				(
				SELECT DISTINCT ON (pa.gid, bdtopo.gid) pa.gid, pa.geom, bdtopo.road_width,  shared_surf_perc
				FROM poubelle_axis AS pa
					, ST_Buffer(pa.geom,10) as pageom
					, bdtopo_x_streetgen_x_odparis.bdtopo_reregistered_cleaned  as bdtopo
					, ST_Buffer(bdtopo.geom,10) AS bdgeom  
					, CAST(ST_Area(ST_Intersection(pageom,bdgeom )) / ST_Area(ST_Union(pageom,bdgeom)) AS float) as shared_surf_perc
				WHERE ST_DWithin(pa.geom, bdtopo.geom,10) = TRUE
				ORDER BY pa.gid, bdtopo.gid, shared_surf_perc DESC 
				) AS unique_poubelle_bdtopo  
			GROUP BY  gid ; 

			SELECT count(*)
			FROM poubelle_axis_approx_width ; 
			
			-- approx road width is now in poubelle_axis_approx_width
	-- now dealing with missing numbers
		--on all poubelle road axis segment, how much have correct numbering information?
		WITH all_numbers AS (
			SELECT adr_dg88 beg , adr_fg88 en, geom, id, nom_1888, 'left' side
			FROM poubelle_src
			UNION ALL 
			SELECT adr_dd88, adr_fd88, geom, id, nom_1888, 'right' side
			FROM poubelle_src
		)
		SELECT count(*) --7127/13732 road axis segment side have complete information for number generation
		FROM all_numbers 
		WHERE historical_geocoding.numerotation2float(beg) != 0 AND historical_geocoding.numerotation2float( en) != 0 
			AND historical_geocoding.numerotation2float(beg) != -1 AND historical_geocoding.numerotation2float(en) != 61
			AND beg IS NOT NULL AND en IS NOT NULL; 


		--generating all the points when possible :  


		
		DROP FUNCTION IF EXISTS poubelle_paris.generate_numbers_points(   road_axis geometry, approx_road_width float, is_left_side boolean, start_number float, end_number float, sidewalk_width float, offset_position float ); 
		CREATE OR REPLACE FUNCTION poubelle_paris.generate_numbers_points(  road_axis geometry, approx_road_width float, is_left_side boolean, start_number float, end_number float, sidewalk_width float, offset_position float )
		RETURNS TABLE(nid int, numbers_value float, number_geom geometry) AS 
			$BODY$
				--@brief : this function generate the numbers for a given segement of road, given the relevant information, using linear interpolation 
				DECLARE      
				BEGIN 
					--RAISE NOTICE 'road_axis : %', ST_AsText(road_axis); 
					BEGIN 
					RETURN QUERY 
					WITH i_data AS (
						SELECT  road_axis,  approx_road_width,  is_left_side
							,  start_number
							,   end_number
							,   sidewalk_width  
							, offset_position
					)
					, n_number_to_create AS (
						SELECT  CAST( ( i.end_number-i.start_number)/2 AS int)   as n_num
						FROM i_data as i
					)
					, preparing_substring AS (
						SELECT CASE WHEN i.is_left_side IS TRUE THEN sub 
							ELSE ST_Reverse(sub) END AS sub
						FROM i_data AS i
							, least(0.4,i.offset_position/ST_Length(St_GeometryN(i.road_axis,1))) AS offset_curv
							,  ST_LineSubstring (St_GeometryN(i.road_axis,1),offset_curv, 1-offset_curv ) as sub
					
					)
					--,curv_abs AS (
						SELECT (row_number() over(order by s ))::int as id, s::float
							,CASE WHEN i.is_left_side IS TRUE THEN ST_LineInterpolatePoint(ngeom, ncurv) ELSE ST_LineInterpolatePoint(ST_Reverse(ngeom), ncurv)  END as interpolated_point
							--,  ncurv
						FROM i_data AS i, n_number_to_create, preparing_substring
							, generate_series( i.start_number::int, i.start_number::int + 2*  n_num::int,  (( i.end_number-i.start_number)/abs( ( i.end_number-i.start_number)) *  2)::int) AS s
							, CAST ((s-i.start_number)/(i.end_number-i.start_number) AS float) AS ncurv
							, ST_OffsetCurve(sub 
								, (i.approx_road_width + i.sidewalk_width))  AS ngeom ; 
				    
				EXCEPTION	
					WHEN others THEN
					RAISE NOTICE 'failed to work on geom %', ST_AsText(road_axis);
					RETURN QUERY SELECT NULL::int, NULL::float, NULL::geometry; 
				END ;
				RETURN ; 
				END ; 
			$BODY$
		LANGUAGE plpgsql  IMMUTABLE STRICT; 

		DROP TABLE IF EXISTS test_generating_number ; 
		CREATE TABLE test_generating_number AS 
		WITH i_data AS (
			SELECT pb.id, pb.geom as road_axis
				, COALESCE(approx.approx_road_width, 9.5::float) as approx_road_width
				, true AS is_left_side
				, historical_geocoding.numerotation2float(adr_dg88) AS start_number
				, historical_geocoding.numerotation2float(adr_fg88) AS end_number
				, 2 AS  sidewalk_width 
				, 10.0 AS  offset_position
			FROM poubelle_src_merged  AS pb LEFT OUTER JOIN poubelle_axis_approx_width as approx ON  (approx.gid = pb.gid::int) 
			WHERE  -- gid = 1436 -- street oriented upward, numbering downward
					--OR  gid = 922 -- street oriented downward, numbering downward
					-- gid = 1835  --street oriented upward, numbering upward
					 pb.gid = 5754 --error case
		)
		SELECT f.*
		FROM i_data 
			, poubelle_paris.generate_numbers_points(road_axis  , approx_road_width , is_left_side , start_number  , end_number, sidewalk_width,offset_position )  as  f ; 

		DROP TABLE IF EXISTS test_generating_number ; 
		CREATE TABLE test_generating_number AS  
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
			SELECT al.gid, nom_1888,normalised_name,historical_name, f.*
			FROM  all_sides AS al
				, historical_geocoding.numerotation2float(start_number  ) AS sn
				, historical_geocoding.numerotation2float(end_number) AS en
				, poubelle_paris.generate_numbers_points(
					road_axis  
					, approx_road_width 
					, is_left_side 
					,sn
					,en
					, 2.0::float --  sidewalk_width
					,10.0::float ) AS f-- offset_position )  as  f  
			WHERE sn !=0 AND en != 0
				AND sn  != -1 AND en::int != -1
				AND sn IS NOT NULL  AND en IS NOT NULL 
				AND abs(sn::int-en::int)>2;
				

	

		DROP TABLE IF EXISTS poubelle_visu_fail_numbering ; 
		CREATE TABLE poubelle_visu_fail_numbering AS
		SELECT pa.*
		FROM test_generating_number
			LEFT OUTER JOIN poubelle_axis AS pa USING (gid) 
		WHERE nid IS NULL ; 


		DROP TABLE IF EXISTS poubelle_visu_contradictory_parity ; 
		CREATE TABLE IF NOT EXISTS poubelle_visu_contradictory_parity AS 
			WITH cleaned_input AS (
				SELECT gid, nom_1888 
					,fg88 ,dg88, fd88,  dd88
					, geom
				FROM poubelle_src_merged
					, CAST(historical_geocoding.numerotation2float(adr_fg88) AS int) AS fg88 , CAST(historical_geocoding.numerotation2float(adr_fd88) AS int) AS fd88 
					,CAST(historical_geocoding.numerotation2float(adr_dg88)AS int) AS dg88 , CAST(historical_geocoding.numerotation2float(adr_dd88) AS int) AS dd88 
				WHERE ( fg88 != 0 OR dg88!=0) AND ( fd88 != 0 OR dd88!=0) 
					AND (fg88 != -1 AND dg88!= -1 AND fd88 != -1 AND dd88 != -1) 
			)
			SELECT *
			FROM cleaned_input 
			WHERE --number on the same side dont have the same parity
				( fg88 != 0 AND dg88 != 0 ) AND (fg88 + dg88)&1 =1 -- if same parity, sum should be par
				OR 
				( fd88 != 0 AND dd88 != 0 ) AND (fd88 + dd88)&1 =1
				OR --number on opposite side should have opposite parity
				(greatest(fg88, dg88) + greatest(fd88, dd88) ) &1 = 0  ; 


		SELECT * --count(*)
		FROM test_generating_number
		-- WHERE numbers_value IS NULL
		WHERE normalised_name IS NOT NULL
		LIMIT 100 ; 

	-- inserting the numbers in the geoloc table
	INSERT INTO poubelle_number (historical_name, normalised_name, geom, specific_fuzzy_date, specific_spatial_precision, historical_source, numerical_origin_process
		, associated_normalised_rough_name
		-- , gid 
		 ,  road_axis_id )
		SELECT historical_geocoding.float2numerotation(numbers_value) || ' '|| historical_name AS historical_name
			,   historical_geocoding.float2numerotation(numbers_value) || ' ' ||  normalised_name  AS normalised_name
			,number_geom AS geom
			,NULL AS specific_fuzzy_date
			,NULL AS specific_spatial_precision 
			, 'poubelle_municipal_paris' AS historical_source
			, 'poubelle_paris_number' AS numerical_origin_process
			, normalised_name
			,   gid
		FROM  
			test_generating_number
			WHERE numbers_value is not null ;

			SELECT *
			FROM poubelle_number
			LIMIT 100 ;
 /*
-- NOTE : to properly generate numbers, we should 
		  
		-- writting a function to estimate the direction of a road regarding the seine.
		-- each point of the road has to be passed into relative coordinates regarding the Seine
			DROP TABLE IF EXISTS seine_axis ; 
			CREATE TABLE IF NOT EXISTS seine_axis(
				gid serial primary key
				,geom geometry(linestring,2154)
			) ; 
			INSERT INTO seine_axis(geom) SELECT ST_GeomFromtext('LINESTRING(654809 6859373,653512 6860706,653027 6861191,652520 6861471,652470 6861790,652315 6861953,651636 6862209,651063 6862331,649912 6862872,648489 6862766,647860 6862187,647034 6861420)',2154); 


			SELECT *
			FROM poubelle_src
			WHERE nom_1888 ILIKE '%bonaparte%' ;  
			 

			WITH input_road_axis AS (
				SELECT *
				FROM poubelle_axis
				WHERE historical_name  ILIKE '%bonaparte%'
				
				LIMIT 100
			)

	
	-- for how much road can we predict the direction of numbering
	-- for how much road can we interpolate 
*/