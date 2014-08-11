
PGDATABASE=belet-seri2
DB:= $(PGDATABASE)
PSQL:= PGDATABASE=$(DB) psql 

all:
		@echo  "install: to setup test db"
		@echo 	"check: run tests"
install:
	createdb $(DB)
	$(PSQL) -c 'create schema pgtap;'
	PGOPTIONS=--search_path=pgtap $(PSQL) -f ./pg_tap/pgtap.sql
	$(PSQL) -f ./db_config.sql 

check:
	./pg_tap/pg_prove --ext=.sql

