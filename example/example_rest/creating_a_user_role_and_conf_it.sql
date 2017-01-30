----------
-- Remi Cura, copyright 2017 , belle epoque, IGN 
--
-- Example of how to set up a geocoding user role with adequate privileges


CREATE ROLE geocoding_user LOGIN  NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION CONNECTION LIMIT 10;
COMMENT ON ROLE geocoding_user IS 'user for geocoding, has almost no right except using the correct functions';


GRANT USAGE ON SCHEMA public,geohistorical_object,historical_geocoding, geocoding_edit TO geocoding_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public, geohistorical_object,historical_geocoding, geocoding_edit TO geocoding_user;
GRANT EXECUTE  ON ALL FUNCTIONS IN SCHEMA public, geohistorical_object,historical_geocoding, geocoding_edit  TO geocoding_user;

GRANT UPDATE,INSERT, DELETE ON ALL TABLES IN SCHEMA geocoding_edit TO geocoding_user ; 
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA geocoding_edit TO geocoding_user;

