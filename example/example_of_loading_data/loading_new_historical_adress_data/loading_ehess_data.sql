------------------------
-- Remi Cura, 2016 , Projet Belle Epoque
------------------------

-- load the data collected by maurizio gribaudi from ehess


DROP SCHEMA  IF EXISTS ehess_data;

CREATE SCHEMA IF NOT EXISTS ehess_data  ;

SET search_path to ehess_data, public ; 

-- starting by loading professiono data at 3 dates
DROP TABLE IF EXISTS profession_raw ; 
CREATE TABLE profession_raw (
	nl text,
	nfsource text,
	nlfs text,
	catP text,
	Professionobs text,
	profession text,
	Profession_complement text,
	detail text,
	NIND text,
	NOMOK text,
	indiv_titre text,
	type_rue text,
	article_rue text,
	nom_rue text,
	num_rue text,
	nom_immeuble text,
	date text,
	source text,
	NINDSUCC text,
	successeur_de text,
	autres_informations_geographiques text,
	autres_infos text
) ;

COPY profession_raw
FROM '/media/sf_RemiCura/DATA/Donnees_belleepoque/ehess/BOTTINS_PROFS_OK.csv'
WITH (FORMAT CSV, HEADER,  DELIMITER ';', ENCODING 'LATIN1'); 
DELETE FROM profession_raw WHERE nl = 'nl' ; --removing first row withheaders


-- select set_limit(0.8) ; 
DROP TABLE IF EXISTS profession_geocoded ; 
CREATE TABLE profession_geocoded AS 
SELECT  nl, catp, professionobs, nind, nomok
		, date AS sdate, source
		, adresse
		, f.*
		, St_Multi(ST_Buffer(f.geom, f.spatial_precision))::geometry(multipolygon,2154) AS fuzzy_geom
FROM profession_raw
	, trim(both ' '::text from 
		COALESCE(num_rue, ' '::text) || ' '::text || 
		COALESCE(type_rue, ' '::text)|| ' '::text || 
		COALESCE(article_rue, ' '::text)|| ' '::text || 
		COALESCE(nom_rue, ' '::text) ) AS adresse_temp
	, CAST((postal_normalize(adresse_temp))[1] AS text) as adresse
	, historical_geocoding.geocode_name(
		query_adress:=adresse
		, query_date:= sfti_makesfti(date::int-1,date::int,date::int,date::int+1)
		, target_scale_range := numrange(0,30)
		, ordering_priority_function := '100 * semantic + 5 * temporal  + 0.01 * scale + 0.001 * spatial '
			, semantic_distance_range := numrange(0.5,1)	
			, temporal_distance_range:= sfti_makesfti(1820,1820,2000,2000)
			, scale_distance_range := numrange(0,30) 
			, optional_reference_geometry := NULL-- ST_Buffer(ST_GeomFromText('POINT(652208.7 6861682.4)',2154),5)
			, optional_spatial_distance_range := NULL -- numrange(0,10000)
		) as f
LIMIT 1000 ;



 
-- now loading another type of data , people with the right to vote in 1844: 


DROP TABLE IF EXISTS censitaire_raw ;
CREATE TABLE IF NOT EXISTS censitaire_raw (
orsid text primary key, 
code_elect text,
ardt_num text,
ardt_alp text,
n_ordre text,
nom text,
prenom text,
profession text,
profession_special text, 
domicile text,
date_naiss text,
tot_contr text,
lieu_paiement text,
lieu_contrib text, 
fonciere text,
person text,
port text,
patente text,
nat_titre text,
motif_retranchement text 
); 



COPY censitaire_raw
FROM '/media/sf_RemiCura/DATA/Donnees_belleepoque/ehess/censitairesParis.csv'
WITH (FORMAT CSV, HEADER, DELIMITER ';', ENCODING 'LATIN1');

--celaning the iunput adresse, it is written in reverse, with shortenings
 SELECT domicile 
	, (postal_normalize(regexp_replace(domicile , '^(.*?)(\d+.*?)$', '\2 \1')))[1]
 FROM censitaire_raw
 LIMIT 1000 ; 


--SELECT set_limit(0.8)

DROP TABLE IF EXISTS censitaire_geocoded ; 
CREATE TABLE censitaire_geocoded AS 
 SELECT orsid, code_elect, nom, prenom, profession, date_naiss, tot_contr, lieu_paiement, lieu_contrib
	, adresse
	, f.*, 
	 St_Multi(ST_Buffer(f.geom, f.spatial_precision))::geometry(multipolygon,2154) AS fuzzy_geom

  FROM censitaire_raw 
	, CAST((postal_normalize(regexp_replace(domicile , '^(.*?)(\d+.*?)$', '\2 \1')))[1] AS text) AS adresse
	, historical_geocoding.geocode_name(
		query_adress:=adresse
		, query_date:= sfti_makesfti(1844-1,1844,1844,1844+1)
		, target_scale_range := numrange(0,30)
		, ordering_priority_function := '100 * semantic + 5 * temporal  + 0.01 * scale + 0.001 * spatial '
			, semantic_distance_range := numrange(0.5,1)	
			, temporal_distance_range:= sfti_makesfti(1820,1820,2000,2000)
			, scale_distance_range := numrange(0,30) 
			, optional_reference_geometry := NULL-- ST_Buffer(ST_GeomFromText('POINT(652208.7 6861682.4)',2154),5)
			, optional_spatial_distance_range := NULL -- numrange(0,10000)
		) as f
 LIMIT 1000 ; 


 -- geocoding not hte censitaire adress, but rather the censitaier hometown


 SELECT *
 FROM ehess_data.censitaire_lieu_contrib_geocoded 
 WHERE lieu_contrib ILIKE '%PARIS%'
 LIMIT 1 
DROP TABLE IF EXISTS ehess_data.censitaire_lieu_contrib_geocoded ; 
CREATE TABLE IF NOT EXISTS ehess_data.censitaire_lieu_contrib_geocoded  AS
INSERT INTO ehess_data.censitaire_lieu_contrib_geocoded
WITH distinct_lieu_contrib AS (
  	SELECT lieu_contrib, count(*) AS  c
	FROM ehess_data.censitaire_raw
	WHERE char_length(lieu_contrib) >= 3
	GROUP BY lieu_contrib
	ORDER BY c DESC
	OFFSET 3 
	SELECT 'paris '|| lieu_contrib || 'e arrondissement' AS lieu_contrib, c
	FROM (
			SELECT lieu_contrib, count(*) AS  c
		FROM ehess_data.censitaire_raw
		WHERE char_length(lieu_contrib) < 3
			AND lieu_contrib ~ '^\d+$'
		GROUP BY lieu_contrib
		ORDER BY c DESC 
		) as sub 
	WHERE c > 1
	
)
SELECT dlc.*, f.rank, f.historical_name, f.normalised_name, ST_Buffer(ST_Centroid(geom), spatial_precision) AS fuzzy_localisation, f.historical_source, f.numerical_origin_process, f. semantic_distance, f.temporal_distance, f.scale_distance, f.aggregated_distance, f.spatial_precision
FROM distinct_lieu_contrib AS dlc
	, historical_geocoding.geocode_name_optimised(
		query_adress:='commune '||lieu_contrib
		, query_date:= sfti_makesfti('01/01/1848'::date) -- sfti_makesftix(1872,1873,1880,1881)  -- sfti_makesfti('1972-11-15');
		, use_precise_localisation := false 
		, ordering_priority_function := '100*(semantic_distance) + 0.1 * temporal_distance + 0.001 * scale_distance +  0.0001 * spatial_distance'
		, max_number_of_candidates := 1
		, max_semantic_distance := 0.2
			, temporal_distance_range := sfti_makesfti(1820,1820,2000,2000) 
			, optional_scale_range := numrange(100,100000)
			, optional_reference_geometry := NULL -- ST_Buffer(ST_GeomFromText('POINT(652208.7 6861682.4)',2154),5)
			, optional_max_spatial_distance := 10000
		) AS  f  ; 
		
CREATE INDEX ON censitaire_lieu_contrib_geocoded USING GIN(lieu_contrib gin_trgm_ops)  ; 

SELECT historical_source, numerical_origin_process, count(*) as tc , sum(c) as sc 
FROM ehess_data.censitaire_lieu_contrib_geocoded
GROUP BY historical_source, numerical_origin_process ;

SELECT *
FROM ehess_data.censitaire_lieu_contrib_geocoded 
LIMIT 1 ; 

SELECT *
FROM ehess_data.censitaire_raw
WHERE lieu_contrib is not null AND char_length(lieu_contrib) > 3
LIMIT 1; 

SELECT set_limit(0.9) ;
CREATE INDEX ON censitaire_raw USING GIN(lieu_contrib gin_trgm_ops) ; 


SELECT set_limit(0.9)
DROP TABLE IF EXISTS ehess_data.censitaire_contrib ; 
CREATE TABLE IF NOT EXISTS ehess_data.censitaire_contrib  AS 
SELECT DISTINCT ON (cl.lieu_contrib , cr.orsid ) 	
	COALESCE(cr.fonciere::int,0)+COALESCE(cr.person::int,0)
		+COALESCE(cr.port::int,0)+COALESCE(cr.patente::int,0) AS tot_contrib, cr.fonciere, cr.lieu_contrib  AS lieu_contrib_init, 
	cl.lieu_contrib, cl.historical_name, cl.normalised_name, cl.historical_source, cl.numerical_origin_process,  cl.fuzzy_localisation
FROM ehess_data.censitaire_lieu_contrib_geocoded AS cl
	, ehess_data.censitaire_raw AS cr
WHERE (cl.lieu_contrib % cr.lieu_contrib AND char_length(cr.lieu_contrib) > 3 )
	OR (char_length(cr.lieu_contrib) < 3
			AND cr.lieu_contrib ~ '^\d+$' AND cl.lieu_contrib % CAST('commune paris '|| cr.lieu_contrib || 'e arrondissement' AS text))
ORDER BY cl.lieu_contrib , cr.orsid , similarity(cl.lieu_contrib, cr.lieu_contrib) DESC ;

 CREATE INDEX ON ehess_data.censitaire_contrib USING GIST(fuzzy_localisation ) ;


SET search_path to ehess_data, rc_lib, public ; 

DROP TABLE IF EXISTS ehess_data.france_hex_val ;
CREATE TABLE ehess_data.france_hex_val AS 
WITH hex AS (
	SELECT row_number() over() as id, ST_SetSRID(hex, 2154) AS hex
	FROM ST_MakeEnvelope(142972,6237196,1105914,7106441) AS france_enveloppe 
		, rc_lib.CDB_HexagonGrid(france_enveloppe,5000) AS hex
)
, adding_data AS (
	SELECT hex.*, sum(  perc * cr.tot_contrib::int) AS sum 
	FROM hex ,ehess_data.censitaire_contrib AS cr
		, CAST( ST_Area(ST_INtersection(hex.hex, cr.fuzzy_localisation)) / ST_Area(hex.hex) AS float) as perc
	WHERE ST_Intersects(hex.hex, cr.fuzzy_localisation) IS TRUE
	GROUP BY hex.id, hex.hex  
	)
, tot AS (
SELECT *
FROM adding_data
UNION ALL 
SELECT id, hex, 0::int AS sum
FROM hex
)
SELECT distinct on ( id) *
FROM tot
ORDER BY id, sum DESC ;
ALTER TABLE ehess_data.france_hex_val ADD PRIMARY KEY (id ) ;
ALTER TABLE ehess_data.france_hex_val ALTER COLUMN hex TYPE geometry(multipolygon,2154) USING ST_Multi(hex)

DROP TABLE IF EXISTS ehess_data.france_hex_val_2 ;
CREATE TABLE ehess_data.france_hex_val_2 AS 
SELECT *
FROM ehess_data.france_hex_val
WHERE sum >0 and sum <10000 ; 

SELECT count(*)
FROM ehess_data.france_hex_val
WHERE sum = 0 

SELECT *
FROM ign_paris.ign_france_town 
WHERE normalised_name ILIKE '%Paris%'
LIMIT 1 

-- now loading another type of data , poeople who get arrested in 1848 after the failed revolution: 


DROP TABLE IF EXISTS prevenu_raw ; 
CREATE TABLE prevenu_raw (
num_ligne text primary key,
num_doublon text,
num_registre text,
ville text,
cod_ban text,
attribut text,
particule text,
nom_rue text,
num_adr text,
nom text,
prenom text,
age text,
profession text,
activite text,
branche text,
lieu_naiss text,
dep_naiss text,
decision text,
sexe text
) ; 



COPY prevenu_raw
FROM '/media/sf_RemiCura/DATA/Donnees_belleepoque/ehess/prevenus_tous_dec_2012.csv'
WITH (FORMAT CSV, HEADER, DELIMITER ';', ENCODING 'LATIN1');

--11644

-- select set_limit(0.8)
DROP TABLE IF EXISTS prevenu_geocoded ; 
CREATE TABLE IF NOT EXISTS prevenu_geocoded AS
SELECT num_ligne, ville
	, num_adr, attribut, particule, nom_rue
	, nom, prenom, age, profession, 
	lieu_naiss,decision
	, adresse
	, f.*
	,  St_Multi(ST_Buffer(f.geom, f.spatial_precision))::geometry(multipolygon,2154) AS fuzzy_geom
FROM prevenu_raw
	, trim(both ' '::text from 
		COALESCE(num_adr, ' '::text) || ' '::text || 
		COALESCE(attribut, ' '::text)|| ' '::text || 
		COALESCE(particule, ' '::text)|| ' '::text || 
		COALESCE(nom_rue, ' '::text)|| ' '::text  ) AS adresse_temp
	, CAST((postal_normalize(adresse_temp))[1] AS text) as adresse
	, historical_geocoding.geocode_name(
		query_adress:=adresse
		, query_date:= sfti_makesfti(1848-1,1848,1848,1848+1)
		, target_scale_range := numrange(0,30)
		, ordering_priority_function := '100 * semantic + 5 * temporal  + 0.01 * scale + 0.001 * spatial '
			, semantic_distance_range := numrange(0.5,1)	
			, temporal_distance_range:= sfti_makesfti(1820,1820,2000,2000)
			, scale_distance_range := numrange(0,30) 
			, optional_reference_geometry := NULL-- ST_Buffer(ST_GeomFromText('POINT(652208.7 6861682.4)',2154),5)
			, optional_spatial_distance_range := NULL -- numrange(0,10000)
		) as f
LIMIT 4000 ; 
 --  SELECT 7741 /8610.0

 SELECT count(*)
 FROM prevenu_geocoded
 WHERE ville ilike 'paris' ;

 SELECT *
 FROM prevenu_geocoded
 LIMIT 10

 SELECT count(*)
 FROM prevenu_raw
, trim(both ' '::text from 
		COALESCE(num_adr, ' '::text) || ' '::text || 
		COALESCE(attribut, ' '::text)|| ' '::text || 
		COALESCE(particule, ' '::text)|| ' '::text || 
		COALESCE(nom_rue, ' '::text)|| ' '::text  ) AS adresse_temp
	, CAST((postal_normalize(adresse_temp))[1] AS text) as adresse
	WHERE adresse is not null AND ville ILIKe 'paris'

 