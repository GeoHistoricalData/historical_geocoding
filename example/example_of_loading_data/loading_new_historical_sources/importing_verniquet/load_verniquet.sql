--------------------------------
-- Rémi Cura, 2016
-- projet geohistorical data
-- 
--------------------------------
-- import et normalisation du plan de Paris de Verniquet de Benoit
-- 
--------------------------------

  CREATE EXTENSION IF NOT EXISTS postgis ; 	
  CREATE SCHEMA IF NOT EXISTS verniquet_paris ; 

  
--load verniquet road axis data with  shp2pgsql
    -- /usr/lib/postgresql/9.5/bin/shp2pgsql -d -I /media/sf_RemiCura/DATA/Donnees_belleepoque/reseau_routier_benoit_20160701/verniquet_l93_utf8_corr.shp verniquet_paris.verniquet_src_axis  > /tmp/tmp_verniquet.sql ;
    --  psql -d geocodage_historique -f /tmp/tmp_verniquet.sql ;

 