47.40. pg_shdepend
The catalog pg_shdepend records the dependency relationships between database
objects and shared objects, such as roles. This information allows PostgreSQL
to ensure that those objects are unreferenced before attempting to delete
them.

See also pg_depend, which performs a similar function for dependencies
involving objects within a single database.

Unlike most system catalogs, pg_shdepend is shared across all databases of a
cluster: there is only one copy of pg_shdepend per cluster, not one per
database.

Table 47-40. pg_shdepend Columns

Name  Type  References  Description
dbid  oid pg_database.oid The OID of the database the dependent object is in,
or zero for a shared object
classid oid pg_class.oid  The OID of the system catalog the dependent object
is in
objid oid any OID column  The OID of the specific dependent object
objsubid  int4    For a table column, this is the column number (the objid and
classid refer to the table itself). For all other object types, this column is
zero.
refclassid  oid pg_class.oid  The OID of the system catalog the referenced
object is in (must be a shared catalog)
refobjid  oid any OID column  The OID of the specific referenced object
deptype char    A code defining the specific semantics of this dependency
relationship; see text
In all cases, a pg_shdepend entry indicates that the referenced object cannot
be dropped without also dropping the dependent object. However, there are
several subflavors identified by deptype:

In all cases, a pg_shdepend entry indicates that the referenced object cannot
be dropped without also dropping the dependent object. However, there are
several subflavors identified by deptype:

SHARED_DEPENDENCY_OWNER (o)
The referenced object (which must be a role) is the owner of the dependent
object.

SHARED_DEPENDENCY_ACL (a)
The referenced object (which must be a role) is mentioned in the ACL (access
control list, i.e., privileges list) of the dependent object. (A
SHARED_DEPENDENCY_ACL entry is not made for the owner of the object, since the
owner will have a SHARED_DEPENDENCY_OWNER entry anyway.)

SHARED_DEPENDENCY_PIN (p)
There is no dependent object; this type of entry is a signal that the system
itself depends on the referenced object, and so that object must never be
deleted. Entries of this type are created only by initdb. The columns for the
dependent object contain zeroes.

Other dependency flavors might be needed in future. Note in particular that
the current definition only supports roles as referenced objects.



