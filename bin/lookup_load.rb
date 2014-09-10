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
         <input_files>...          input file names [required]
         -debug                    enable debugging 
                                      { $DEBUG = true }
         --debug                   [ditto]
EOF

DESKTOP ={:adapter => 'postgresql', :port=>5432, :database=>'iso'}

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
FIND_TABLE  = "select count(*) as n from information_schema.tables where table_name = ? and table_schema = ?"
["information_schema.tables", 'table_name','table_schema']
FIND_DOMAIN = "select count(*) as n from information_schema.domains where domain_name = ? and domain_schema  = ? "
["information_schema.domains", 'domain_name', 'domain_schema'] 

class Catalog < ActiveRecord::Base
    def self.entity_exists?(data_type, name, qualifier)
      rc = case data_type 
      when :table
          x(sq([FIND_TABLE, name, qualifier]))
      when :schema
          x(sq([FIND_SCHEMA, name]))
      when :domain
          x(sq([FIND_DOMAIN, name, qualifier]))
      else
        raise Exception.new("Unsupported Type #{data_type}: (#{name},#{qualifier})")
      end
      rc.values.first.first.to_i > 0 #, rc['n'].inspect 
    end
    def self.sql_name(name, schema=nil)
        n = connection.quote_table_name(name)
        if schema.nil? 
          n
        else
          s = connection.quote_table_name(schema)
          "#{s}.#{n}"
        end
    end
    def self.schema_comment(name, desc)
        mkcomment(:schema, name, nil, desc)
    end
    def self.domain_comment(name, schema, desc)
        mkcomment(:domain, name, schema, desc)
    end
    def self.table_comment(name, schema, desc)
        mkcomment(:table , name, schema, desc)
    end
    def self.mkcomment(type, name, schema, desc)
      n = sql_name(name, schema)
      x(sq(["comment on #{type.to_s} #{n} is ?", desc]))
    end

    def self.mkschema(name) 
        n = connection.quote_table_name(name)
        x("create schema #{n}")
    end
    def self.mk_lookup_table(table_name, schema, value_col)
      n = sql_name(table_name, schema)
      x( %Q(create table #{n} ) +
         %Q@("#{value_col}" text unique, description text )@
        )
    end
    def self.mkdomain(domain_name, schema, body)
      n = sql_name(domain_name, schema)
      x( "CREATE DOMAIN #{n} AS #{body}" )
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
  def self.key_columns(key_list)
      key_list.map{|col| connection.quote_column_name(col)}.join(',')
  end
end

class DatabaseBuilder
  attr :input_data
  attr :dbobj_type

  def initialize(inData)
    @input_data = inData
    @dbobj_type = inData[:type]
  end
  def build()
    if supports_type?(@dbobj_type) then
       send("#{@dbobj_type}_type".to_sym, @input_data)
#    case @dbobj_type
#    when 'lookup' then
#      puts lookup_type(inData)
#    when 'schema' then
#      puts schema_type(inData)
#    when 'domain' then
#      puts domain_type(inData)
    else
      "Unsupported type #{@dbobj_type}"
    end

  end
  def create_schema(schema) 
    unless  Catalog.entity_exists?(:schema,schema, nil) then
        Catalog.mkschema schema
    end
  end
  def domain_type(inData)
    dbobj_type = inData[:type]
    schema = inData[:schema]
    domain = inData[:domain]
    desc = inData[:description]
    body = inData[:values] 
    create_schema(schema) 
    unless Catalog.entity_exists?(:domain, domain, schema) then 
        Catalog.mkdomain(domain, schema, body)
    end
    Catalog.domain_comment(domain, schema, desc)
    "Created Domain: #{domain}"
  end
  def schema_type(inData)
    dbobj_type = inData[:type]
    schema = inData[:schema]
    desc = inData[:description]

    create_schema(schema) 
    Catalog.schema_comment(schema, desc)
    "Created Schema: #{schema}"
  end
  def lookup_type(inData)
    dbobj_type = inData[:type]
    schema = inData[:schema]
    table  = inData[:table]
    value_col = inData[:name ]
    desc = inData[:description]
    unless  Catalog.entity_exists?(:schema,schema, nil) then
        Catalog.mkschema schema
    end
    unless Catalog.entity_exists?(:table, table, schema) then 
        Catalog.mk_lookup_table(table, schema, value_col)
    end
    Catalog.table_comment(table, schema, desc)

    raw_data = inData[:values]
    raw_count = raw_data.length 

    LookupTable.table_name = "#{schema}.#{table}"
    cnt = LookupTable.count
    if cnt < 1 then
      case
      when Hash then
        LookupTable.mass_insert([value_col,'description'],
            raw_data.map{|h| [h[:value], h[:description]]})
      else
        LookupTable.mass_insert([value_col],raw_data)
      end
      "Inserted #{LookupTable.count} rows of #{raw_count}"
    elsif cnt == raw_count
      "The data looks correct"
    else
      "The data is not correct"
    end
  end
  def supports_type?(type) 
    methods.map{|v| v =~ /#{type}_type/ }.compact.length == 1 
  end
end

def connect(connection_url)
    access = PostgresAccess::Parse.new(connection_url)
    ActiveRecord::Base.establish_connection(access.connect)
end
def main()
    STDERR.puts @args.inspect if $DEBUG
    if @args['-c'] == 'chad' then
        connect(DESKTOP)
    else
        connect(@args['-c'])
    end
    @args['<input_files>'].each {|infile| 
      inData = YAML.load_file(infile)
      puts inData
      builder = DatabaseBuilder.new(inData)
      puts builder.build()
    }
end
main()
