begin;

create schema pgtap;

set search_path = 'pgtap','public';
\ir pgtap.sql

commit;
