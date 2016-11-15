--------------------------------
-- Rmi Cura, 2016
-- projet geohistorical data
-- 
--------------------------------
-- fonction reconnaissant et exploitant la numrotation de rue francaise
-- pour deux numros donns 48 bis, 48-A, 48A etc
-- on veut pouvoir les ordonner
-- on passe par une etape de parsing, puis des regles d'ordonnancement
--
-- note : fonctions testes avec succs sur les donnes open street map ile de france
-- cas d'echec : normalisation : aucun
-- cas d'echec : numerotation2float : robuste aux erreur d'orth, sauf "66is" -> "66I"->"66.09"
--------------------------------
	-- CREATE SCHEMA IF NOT EXISTS historical_geocoding ; 
	-- CREATE EXTENSION IF NOT EXISTS pg_trgm  ; 

	
	DROP FUNCTION IF EXISTS historical_geocoding.normaliser_numerotation(numerotation text) ;
	CREATE OR REPLACE FUNCTION historical_geocoding.normaliser_numerotation(numerotation text, OUT numero int, OUT suffixe text)   AS 
	$$
		-- le format accept en entr est D*%*W*, avec D des chiffres, % des characteres de separation non chiffre non lettre, et W des lettres
	DECLARE
		_r record; 
		_numero text;
		_suffixe text; 
		
	-- on essaye de sparer le numro du reste
	BEGIN 
		SELECT NULL, NULL INTO numero, suffixe ; 
		SELECT ar[1] AS numero, ar[2] as suffixe INTO _numero,_suffixe FROM  regexp_matches(trim( both ' ' from numerotation), '([\-]{0,1}[0-9]*).*?([a-zA-Z]*)') AS ar ; 
		--RAISE NOTICE '%, %', _numero,_suffixe ; 
		IF _numero <> ''THEN 
			numero := _numero::int ; 
		ELSE 
			numero := NULL ;
		END IF ; 

		IF _suffixe <> ''THEN 
			suffixe := _suffixe ; 
		ELSE 
			suffixe := NULL ; 
		END IF ; 
		RETURN ;
	END;
	$$
	LANGUAGE 'plpgsql' IMMUTABLE STRICT ; 

	--design
	SELECT *
	FROM CAST('-48s' AS text) as numerotation,  regexp_matches(trim( both ' ' from numerotation), '([\-]{0,1}[0-9]*).*?([a-zA-Z]*)') AS ar  ; 
	
	-- test
	SELECT *
	FROM historical_geocoding.normaliser_numerotation('-48s') ;

	


	
	-- creation d'une table de suffixe autoris et de leur poid relatif, pour l'ordonnancement 
	DROP TABLE IF EXISTS historical_geocoding.ordonnancement_suffixe ; 
	CREATE TABLE IF NOT EXISTS historical_geocoding.ordonnancement_suffixe(
	gid serial  PRIMARY KEY,
	suffixe text,
	ordonnancement float
	);  

	INSERT INTO historical_geocoding.ordonnancement_suffixe(suffixe, ordonnancement) VALUES
		('ANTE',-0.01),
		('A',0.01),('B',0.02),('C',0.03),('D',0.04),('E',0.05),('F',0.06),('G',0.07),('H',0.08),('I',0.09),('J',0.10),('K',0.11)
			,('L',0.12),('M',0.13),('N',0.14),('O',0.15),('P',0.16),('Q',0.17),('R',0.18),('S',0.19) --,('T',0.20)
			,('U',0.21),('V',0.22),('W',0.23),('X',0.24),('Y',0.25),('Z',0.26)
		,('BIS',0.02),('TER',0.03),('QUATER',0.04),('QUINQUIES',0.05),('SEXIES',0.06),('SEPTIES',0.07),('OCTIES',0.08),('NONIES',0.09)
		,('SIXTE',0.06) ; 





	DROP FUNCTION IF EXISTS historical_geocoding.numerotation2float(numerotation text) ;
	CREATE OR REPLACE FUNCTION historical_geocoding.numerotation2float(numerotation text) 
	RETURNS float AS 
	$$
		-- le format accept en entr est D*%*W*, avec D des chiffres, % des characteres de separation non chiffre non lettre, et W des lettres
	DECLARE
	-- on separe numro et suffixe,. Pour chaque siffixe, on regarde quel modulateur correspond dans la liste des suffixe, puis on retourne le numro modifi
		_num int  ; 
		_suff text := NULL;
		_ord float ; 
	BEGIN 
		SELECT numero, suffixe INTO _num, _suff
		FROM  historical_geocoding.normaliser_numerotation(numerotation)
		LIMIT 1 ;

		IF _suff IS NULL AND _num IS NULL OR _num IS NULL THEN 
			RAISE NOTICE  'la numerotation "%" n a pas pu tre dcompose en une paire numr+suffixe',numerotation ; 
			RETURN NULL ; 
		END IF;

		IF _suff IS NULL THEN 
		return _num ; 
		END IF;
 
		--on cherche le suffixe le plus appropri
		SELECT ordonnancement INTO _ord
		FROM  historical_geocoding.ordonnancement_suffixe as suf
		ORDER BY similarity(_suff,suf.suffixe) DESC
		LIMIT 1 ; 

		IF _ord IS NULL OR _ord = 0 THEN -- pas de suffixe correspondant
			RETURN _num ; 
		END IF ;

		RETURN _num + _ord ;  
		
	END;
	$$
	LANGUAGE 'plpgsql' IMMUTABLE STRICT ;  

	--test
	SELECT historical_geocoding.numerotation2float('48 ante')  ;



	DROP FUNCTION IF EXISTS historical_geocoding.float2numerotation(inumf float, OUT numerotation text) ;
	CREATE OR REPLACE FUNCTION historical_geocoding.float2numerotation(inumf float, OUT numerotation text)  AS 
	$$
		-- le format en entr est un float, la sortie du texte par exe : 12.02 -> 12Bis
	DECLARE 
	BEGIN   
		BEGIN
			SELECT DISTINCT ON (ordonnancement) floor(inumf)::int::text || suffixe INTO numerotation
			FROM historical_geocoding.ordonnancement_suffixe AS os
			WHERE os.ordonnancement = round((inumf- floor(inumf))::numeric,3)
			ORDER BY ordonnancement, char_length( suffixe) DESC ; 
		EXCEPTION 
			WHEN others THEN
			numerotation :=  inumf::int::text ; 
			RETURN ; 
		END;
		IF numerotation IS NULL THEN
		numerotation :=  inumf::int::text ; 
		END IF ;

		RETURN ; 

	END;
	$$
	LANGUAGE 'plpgsql' IMMUTABLE STRICT ;  

	--test
	SELECT historical_geocoding.float2numerotation('48.58')  ;
 


	DROP FUNCTION IF EXISTS historical_geocoding.estContigueA(numerotation1 text, numerotation2 text, OUT estContigueA boolean) ;
	CREATE OR REPLACE FUNCTION historical_geocoding.estContigueA(numerotation1 text, numerotation2 text, OUT estContigueA boolean)   AS 
	$$
	DECLARE   
	BEGIN  
		estContigueA :=  historical_geocoding.estContigueA(historical_geocoding.numerotation2float(numerotation1 ), historical_geocoding.numerotation2float(numerotation2)) ;
		RETURN ; 
	END ; 
	$$
	LANGUAGE 'plpgsql' IMMUTABLE STRICT ; 

	

	DROP FUNCTION IF EXISTS historical_geocoding.estContigueA(numerotation1 float, numerotation2 float, OUT estContigueA boolean) ;
	CREATE OR REPLACE FUNCTION historical_geocoding.estContigueA(numerotation1 float, numerotation2 float, OUT estContigueA boolean)   AS 
	$$
		-- prend deux numerotation, puis regarde si ces deux numerotations peuvent etre contigues, par exemple 5 et 7 sont contigue, comme 5 et 7a,
		-- comme 4 et 5 (numerotation des places)
	DECLARE  
		_num1f float := numerotation1;
		_num2f float := numerotation2; 
	BEGIN 
		 -- converti chaque numerotation en un float
		 -- trier du plus petit au plus gros 
		 -- dans tous les cas : dist <3
		 -- si deux suffixe : 
		 -- si un suffixe : 
			-- si suffixe du bas : 
		 -- la distance ntre les deux floats devrait etre <3
		 estContigueA := abs(_num1f - _num2f) < 3 ; 

		_num1f := LEAST(_num1f,_num2f) ;
		_num2f := GREATEST(_num1f,_num2f) ;

		-- RAISE NOTICE '% %', _num1f, _num2f ; 
		
		 -- si dist >= 3 : ne peut pas etre contigue
		 IF abs(_num1f - _num2f) >=3 THEN
			estContigueA := FALSE
			RETURN ; 
		 END IF ; 

		 -- si pas de suffixe pour les deux : la distance doit etre inferrieur ou egal a deux
		 IF _num1f = _num1f::int AND _num2f= _num2f::int THEN
			estContigueA := abs(_num1f - _num2f) <=2;  
			RETURN ; 
		 END IF ;

		 --si le premier numero a un suffixe , la distance au deuximee numero doit etre inferieur a 3, on ne peut pas en dire plus

		IF _num2f !=  _num2f::int THEN  
			IF abs(_num2f  -  _num2f::int -  0.01 ) < 0.0001THEN -- cas ou c'est le premier suffixe de ce numero  
				-- si le suffixe est 0.1: le deuxieme numero  ne doit pas etre le meme numero 
				estContigueA :=  _num1f::int !=  _num2f::int ; 
				RETURN ; 
			END IF ;  
			estContigueA :=  abs(_num2f-0.01  -   _num1f) < 0.0001 ;
		END IF ; 
		 -- si le deuxieme numero a un suffixe 
			-- si le suffixe est 0.1: le deuxieme numero doit etre le meme numero
			-- sinon , le suffixe doit etre celui d'avant
 
		RETURN ;
	END;
	$$
	LANGUAGE 'plpgsql' IMMUTABLE STRICT ; 

	SELECT historical_geocoding.estContigueA(n1, n2)
	FROM CAST('48 ' AS text) AS n1
		, CAST('50' AS text) AS n2 ; 

		
	SELECT historical_geocoding.estContigueA(48,48.02)  ; 
	
	

 DROP FUNCTION IF EXISTS historical_geocoding.number_distance(number_1 text, number_2 text, OUT number_dist float) ;
	CREATE OR REPLACE FUNCTION historical_geocoding.number_distance(number_1 text, number_2 text, OUT number_dist float) AS 
	$$
	DECLARE 
	BEGIN 
		SELECT COALESCE(abs(num1-num2) + ((abs(num1::int-num2::int)%2)=1)::int* 10,10::int)  INTO number_dist
		FROM historical_geocoding.numerotation2float(number_1) AS num1
			, historical_geocoding.numerotation2float(number_2) AS num2 ;  
		RETURN ;
	END; $$ LANGUAGE 'plpgsql' IMMUTABLE CALLED ON NULL INPUT ; 

SELECT historical_geocoding.number_distance('12A','14B') ;
	