#!/usr/bin/env ruby
#
# usage: depends -c <connection_string>
# arg parsing to handle db conn info
#
# graphviz optiosn
# ruby bin/depends.rb -c pgenv > out-charting2.dot
#
# circo -Tpdf -o out1.pdf out-charting2.dot 
# neato -Tpdf -o out1.pdf out-charting2.dot 
# patchwork -Tpdf -o out1.pdf out-charting2.dot 
#

require "rubygems"
require "bundler/setup"

Bundler.require

require 'active_record'
require 'Getopt/Declare'
require 'csv'
require 'pathname'

$: << (Pathname.new(__FILE__).dirname + "../lib").expand_path

require 'postgres_access'
require 'dot'



$DEBUG = false
@args = Getopt::Declare.new(<<EOF)
         undirected                undirected graph
         -c <connection_string>    connection string for access db 
         -o <output_file>          Output filename
         -debug                    enable debugging 
                                      { $DEBUG = true }
EOF

DESKTOP ={:adapter => 'postgresql', :port=>5432, :database=>'depends'}

@depends_query =<<-EOQ
/* non-pinned objects*/
select 
 d.deptype as deptype
, d.objid as obj_oid
, o.type as obj_type, o.schema as obj_schema, o.name as obj_name
, o.identity as obj_identity
, r.type as ref_type, r.schema as ref_schema, r.name as ref_name
, r.identity as ref_identity
, d.refobjid as ref_oid
from pg_depend d
, pg_identify_object(d.classid,d.objid,d.objsubid) o 
, pg_identify_object(d.refclassid,d.refobjid,d.refobjsubid) r
where 
/* only do dependent, auto, and extension deptypes */
deptype in ('n','a','e') /* ignore pinned & internal */
and
(o.schema is null or o.schema not in ('pg_catalog','information_schema'))
and
(r.schema is null or r.schema not in ('pg_catalog','information_schema'))
EOQ

@pinned_depends_query =<<-EOQ
/*pinned objects */
select 
 d.deptype as deptype
, d.objid as obj_oid
, null as obj_type, null as obj_schema, null as obj_name
, null as obj_identity
, r.type as ref_type, r.schema as ref_schema, r.name as ref_name
, r.identity as ref_identity
, d.refobjid as ref_oid
from pg_depend d
, pg_identify_object(d.refclassid,d.refobjid,d.refobjsubid) r
where /* only do pinned deptype */
deptype = 'p'
EOQ
module ActiveRecord
  class Base
    def self.safe_query(query_with_args)
      ActiveRecord::Base.send(:sanitize_sql_array,query_with_args)
    end
    def safe_query(query_with_args)
      self.class.safe_query(query_with_args)
    end
  end
end



class Catalog < ActiveRecord::Base
end
class Pinned < ActiveRecord::Base
  self.table_name ='pinned'
end
class Depend < ActiveRecord::Base
  self.table_name ='depends'
end


class DepType
  DESCRIPTIONS = {
  "n" => "Dependency Normal",
  "a" => "Dependency Auto",
  "i" => "Dependency Internal",
  "e" => "Dependency Extension",
  "p" => "Dependency Pin" ,
  }
end

def main()
    STDERR.puts @args.inspect if $DEBUG
    if @args['-c'] == 'chad' then
        connection_url = DESKTOP
    else
        connection_url = @args['-c']
    end
    outputfn = @args['-o'] 

    access = PostgresAccess::Parse.new(connection_url)
    ActiveRecord::Base.establish_connection(access.connect)

    [['depends',@depends_query],['pinned', @pinned_depends_query ]
      ].each {|name,query|
      Catalog.connection.execute("create or replace view #{name} as #{query}")
    }
    x = Depend.where("obj_schema not in ('pg_catalog', 'information_schema', 'pg_toast')").all

    fmt = DotGraph.new(@args['undirected'])
    fmt.banner("// Found #{x.length} elements")
    root_node = DotNode.new('Database','rootdb','root')

    fmt.root(root_node)
    x.each do |rec|
        next unless DotShape.known_type?(rec.obj_type) 
        obj = DotNode.build(rec.obj_name,rec.obj_identity, rec.obj_type)
        ref = DotNode.build(rec.ref_name,rec.ref_identity, rec.ref_type) 
        fmt.segment(rec.deptype, obj, ref)
        if rec.ref_type == 'schema' then
          fmt.segment('n', ref, root_node) 
        end
        if rec.obj_type == 'schema' then
          fmt.segment('n', obj, root_node) 
        end
    end
    if outputfn then
      File.open(outputfn, 'w') {|io|
        io.puts fmt.to_s
      }
    else
       puts fmt.to_s
    end
    STDERR.puts fmt.debug if $DEBUG
end
main()
