belet-seri
==========

Belet-Seri: Scribe of the Underworld/Recorder of Human Activities

This is a tool to manage realtional databases and datawarehouses.

Manage Database Objects
-----------------------

A database objects is a DDL entitiy in the database that is being managed.
It can also be data where there the data is used as a lookup table or a small
subset of data that is not part of the primary application or which will not
be managed by usualy DML from the applications.

This data has a the following properties:
 - Small set
 - Write once and read often
 - Changes to it are insert only
 - Any deletes will be of unused values only
 - Delete of used values will require custom app or data base changes

The type of objects that are or will be supported are as follows:
 - Schema
 - Tables
 - Views
 - Foreign Tables
 - Functions
 - Domains
 - Triggers
 - Lookup tables
 - Comments














References
----------

1.  [Wikipedia](http://en.wikipedia.org/wiki/Belet-Seri)
2.


