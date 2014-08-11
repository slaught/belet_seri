--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = chad, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: depends_types; Type: TABLE; Schema: chad; Owner: chad; Tablespace: 
--

CREATE TABLE depends_types (
    obj_type text
);


ALTER TABLE chad.depends_types OWNER TO chad;

--
-- Data for Name: depends_types; Type: TABLE DATA; Schema: chad; Owner: chad
--

COPY depends_types (obj_type) FROM stdin;
conversion
language
table constraint
materialized view column
operator family
view column
materialized view
text search dictionary
toast table column
function of access method
operator
view
index
schema
operator of access method
extension
aggregate
function
rule
operator class
domain constraint
sequence
server
foreign-data wrapper
table
text search configuration
table column
foreign table column
type
foreign table
user mapping
default value
text search template
cast
\.


--
-- PostgreSQL database dump complete
--

