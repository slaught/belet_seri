
create view depends 
as 
select 
d.*, c.relname, c.relkind, c2.relname,c2.relkind
from pg_depend d 
join pg_class c on d.classid = c.oid
join pg_class c2 on d.refclassid = c2.oid
;
create view depends
as
select
d.*
, c.relname as dependent_name, c.relkind as dependent_kind
, c2.relname as ref_name, c2.relkind as ref_kind
from pg_depend d
join pg_class c on d.classid = c.oid
join pg_class c2 on d.refclassid = c2.oid
;



classid oid pg_class.oid  The OID of the system catalog the dependent object
is in
objid oid any OID column  The OID of the specific dependent object
objsubid  int4    For a table column, this is the column number (the objid and
classid refer to the table itself). For all other object types, this column is
zero.
refclassid  oid pg_class.oid  The OID of the system catalog the referenced
object is in
refobjid  oid any OID column  The OID of the specific referenced object
refobjsubid int4    For a table column, this is the column number (the
refobjid and refclassid refer to the table itself). For all other object
types, this column is zero.
deptype char    A code defining the specific semantics of this dependency
relationship; see text
In all cases, a pg_depend entry indicates that the referenced object cannot be
dropped without also dropping the dependent object. However, there are several
subflavors identified by deptype:



