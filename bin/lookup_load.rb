#!/usr/bin/env ruby
#
# usage: lookup_load -c <connection_string> file.yml
# arg parsing to handle db conn info
#

require "rubygems"
require "bundler/setup"

Bundler.require

require 'active_record'
require 'Getopt/Declare'
require 'csv'
require 'pathname'
require 'set'

$: << (Pathname.new(__FILE__).dirname + "../lib").expand_path
require 'postgres_access'

$DEBUG = false

@args = Getopt::Declare.new(<<EOF)
         -c <connection_string>    connection string for access db  [required]
         -i <input_file>           input file name [required]
         -debug                    enable debugging 
                                      { $DEBUG = true }
EOF

DESKTOP ={:adapter => 'postgresql', :port=>5432, :database=>'iso'}

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

module ActiveRecord

  class Base
    def self.safe_query(query_with_args)
      ActiveRecord::Base.send(:sanitize_sql_array,query_with_args)
    end
    def safe_query(query_with_args)
      self.class.safe_query(query_with_args)
    end
    alias_method :sq, :safe_query
    def self.sq(a) 
        self.safe_query(a) 
    end
    def self.x(query) 
       connection.execute(query) 
    end 
    def self.execute(query) 
       connection.execute(query) 
    end 
  end
end

FIND_SCHEMA = "select count(*) as n from information_schema.schemata where schema_name = ?"
["information_schema.schemata", "schema_name"]
FIND_TABLE = "select count(*) as n from information_schema.tables where table_name = ? and table_schema = ?"
["information_schema.tables", 'table_name','table_schema']

@find_table = <<EQ1
select count(*) from informat

EQ1

class Catalog < ActiveRecord::Base
    def self.entity_exists?(data_type, name, qualifier)
      rc = case data_type 
      when :table
          x(sq([FIND_TABLE, name, qualifier]))
      when :schema
          x(sq([FIND_SCHEMA, name]))
      else
        raise Exception.new("Unsupported Type #{data_type}: (#{name},#{qualifier})")
      end
      rc.values.first.first.to_i > 0 #, rc['n'].inspect 
    end
    def self.schema_comment(name, desc)
        n = connection.quote_table_name(name)
        x(sq(["comment on schema #{n} is ?", desc]))
    end
    def self.mkschema(name) 
        n = connection.quote_table_name(name)
        x("create schema #{n}")
    end
    def self.mk_lookup_table(table_name, schema, value_col)
      x( %Q(create table "#{schema}"."#{table_name}" ) +
           %Q@("#{value_col}" text unique, description text )@
        )
    end
end

class SpecialKey
  attr_accessor :id_str
  @@idobjects  = Hash.new
  def self.build(s)
    i = @@idobjects[s] 
    if i.nil? then
      i = new(s)
      @@idobjects[s] = i 
    end
    i 
  end
  def initialize(s)
    @id_str = s.gsub('"','_') 
  end
  def to_s
   %Q("#{@id_str}")
  end
  def eql?(other)
    self == other
  end
  def <=>(other)
    self.id_str <=> other.id_str
  end
  def ==(other)
    (other.class == self.class) and (other.id_str == self.id_str )
  end
  def hash()
    @id_str.hash
  end
end

def connect(connection_url)
    access = PostgresAccess::Parse.new(connection_url)
    ActiveRecord::Base.establish_connection(access.connect)
end

class LookupTable < ActiveRecord::Base

  def self.build_record(data)
    case data
    when Array then
      build_record_array(data)
    when String then
      build_record_array([data])
    else
        raise Exception.new("unsupported build_record class #{data.class}")
    end
  end
#  def self.build_single_record(data)
#    z =safe_query(["?",data]) 
#     "(#{z})" 
#  end
  def self.build_record_array(data)
     z = data.map{|x| safe_query(["?",x]) }
     "(#{z.join(',')})" 
  end
  def self.insert_values(raw_data)
     values = raw_data.map{ |rec| build_record(rec)  }.join(',')
    "VALUES #{values}"
  end
  def self.mass_insert(key_list,raw_data)
    v = insert_values(raw_data)
    c = key_columns(key_list)
    t = connection.quote_table_name(table_name)
    execute "INSERT INTO #{t} (#{c}) #{v}"
  end
  def self.key_colums(key_list)
      key_list.map{|col| connection.quote_column_names(col)}.join(',')
  end
end
def schema_type(inData)
    dbobj_type = inData[:type]
    schema = inData[:schema]
    desc = inData[:description]
    unless  Catalog.entity_exists?(:schema,schema, nil) then
        Catalog.mkschema schema
    end
    Catalog.schema_comment(schema, desc)
    "Created Schema: #{schema}"
end
def lookup_type(inData)
    dbobj_type = inData[:type]
    schema = inData[:schema]
    table  = inData[:table]
    value_col = inData[:name ]
    unless  Catalog.entity_exists?(:schema,schema, nil) then
        Catalog.mkschema schema
    end
    unless Catalog.entity_exists?(:table, table, schema) then 
        Catalog.mk_lookup_table(table, schema, value_col)
    end
    raw_data = inData[:values]
    
    LookupTable.table_name = "#{schema}.#{table}"
    cnt = LookupTable.count
    if cnt < 1 then
      LookupTable.mass_insert([value_col],raw_data)
      "Inserted #{LookupTable.count} rows of #{raw_data.length}"
    elsif cnt == raw_data.length
      "The data looks correct"
    else
      "The data is not correct"
    end
end
def main()
    STDERR.puts @args.inspect if $DEBUG
    if @args['-c'] == 'chad' then
        connect(DESKTOP)
    else
        connect(@args['-c'])
    end

#      Catalog.connection.execute("create or replace view #{name} as #{query}")
#    x = Depend.where("obj_schema not in ('pg_catalog', 'information_schema', 'pg_toast')").all
    inData = YAML.load_file(@args['-i'])
    puts inData
    dbobj_type = inData[:type]
    case dbobj_type
    when 'lookup' then
      puts lookup_type(inData)
    when 'schema' then
      puts schema_type(inData)
    else
      puts "Unsupported type #{dbojb_type}"
    end
end
main()
