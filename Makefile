EXTENSION    = historical_geocoding
EXTVERSION   = $(shell grep default_version $(EXTENSION).control | sed -e "s/default_version[[:space:]]*=[[:space:]]*'\\([^']*\\)'/\\1/")
INPUT        = \
	src/020_create_base_historical_geocoding_model.sql \
	src/030_support_functions_for_building_number.sql \
	src/040_function_for_input_adress.sql \
	src/050_geocoding_api.sql
DOCS         = $(wildcard doc/*.md)
PG_CONFIG    = pg_config

all: $(EXTENSION)--$(EXTVERSION).sql

$(EXTENSION)--$(EXTVERSION).sql: src/*.sql
	cat $(INPUT) > $@

EXTRA_CLEAN = $(EXTENSION)--$(EXTVERSION).sql
DATA        = $(EXTENSION)--$(EXTVERSION).sql

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
