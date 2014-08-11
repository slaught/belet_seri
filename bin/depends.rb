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
require 'set'

$: << (Pathname.new(__FILE__).dirname + "../lib").expand_path

require 'postgres_access'



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

class DotLabel
  attr_reader :label
  def initialize(_label)
      @label = _label.to_s.gsub('"',"\\\"")
  end
  def attribute
    %Q(label="#{@label}")
  end
end
class DotElement
  attr_accessor :attribute_list
  def initialize()
    @attribute_list = Array.new
  end
  def attribute_add(attr)
    @attribute_list.push(attr)
  end
  def attributes
    l = @attribute_list.compact
    return '' if l.empty? 
    ll = l.map(&:attribute).join(", ")
    "[#{ll}]"
  end
end
class DotID
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
class DotShape 
  attr_reader :shape
  attr_accessor :color
  @@flyweight = nil 

  def self.build_flyweights()
    @@flyweight = Hash.new( new("none") )
    TYPE_TO_SHAPE.keys.each{|key|
      @@flyweight[key] = new(key)
    } 
    if $DEBUG
      STDERR.puts TYPE_TO_SHAPE.inspect
      STDERR.puts @@flyweight.inspect
    end
  end
  def inspect()
    "#<DotShape:#{object_id} #{@shape} #{color}>"
  end
  def self.build(type)
      @@flyweight[type] 
  end
  def initialize(type)
    x = TYPE_TO_SHAPE[type]
    if x.nil? then
      @shape = "none" 
      @color = nil
    else
      @shape = x  
    end
    @color = SHAPE_TO_COLOR[@shape]
  end
  def self.known_type?(t)
    TYPE_TO_SHAPE.has_key?(t)
  end
  SHAPE_TO_COLOR = {
    "square" => "8",
    "box3d" => "7" ,
    "house" => "6" ,
    "triangle" =>"5" ,
    "tripleoctagon" => "4",
    "doublecircle" => "3",
    "oval" => "1" , 
    "triplecircle" => "10"
  }
  TYPE_TO_SHAPE = { #/*
    "root" => "tripleoctagon",
    "table" => "square",
    "server" => "box3d",
    "materialized view" => "house",
    "view" => "triangle",
    "foreign-data wrapper" => "doubleoctagon",
    "foreign table" => "doublecircle",
    "schema" => "oval", # folder
    "rule" => "plaintext",
  }    
  def attribute
    if color.nil? then
      c = ''
    else
      c = %Q(,color="//#{color}") 
    end
    %Q(shape="#{shape}"#{c})
  end
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

class DotNode < DotElement
  attr_accessor :identity
  @@nodes = Hash.new

  def self.build(name, ident, type)
    n = @@nodes[ident]  
    if n.nil? then
      n = DotNode.new(name,ident,type)
      @@nodes[ident] = n
    end
    n
  end
  def initialize(name, ident, type) # label,identity,shape)
      super()
      @identity = DotID.build(ident)
      self.attribute_add(DotShape.build(type)) 
      unless name.nil?
        self.attribute_add(DotLabel.new(name)) 
      end
  end
  def to_s
     %Q(#{identity} #{attributes} )
  end
  def <=>(other)
    self.identity <=> other.identity
  end
  def ==(other)
    (other.class == self.class) and (other.identity.eql?(identity))
  end
  def eql?(other)
    self == other
  end
end
class DotEdge  < DotElement
  attr_accessor :edge
  @@connector = '->'
  def self.undirected()
      @@connector = '--'
  end
  def initialize(label, node1, node2)
      super()
      self.edge = Array[node1, node2]
      self.attribute_add(DotLabel.new(label)) unless label.nil?
  end
  def to_s
      %Q(#{edge.first.identity} #{@@connector} #{edge.last.identity} #{attributes})
  end
  def eql?(other)
      self == other 
  end
  def ==(other)
    (other.class == self.class) and \
       ( other.edge.first == self.edge.first) and \
       ( other.edge.last  == self.edge.last )
  end
  def hash()
    edge.hash
  end
     
end
class DotGraph 
 
  def debug
    values = @debug.each_cons(2).map{|x| x.first.eql? x.last }
    %Q(
#{@nodes.sort[0..10]}
@nodes.length #{@nodes.length}
@nodes.uniq.length #{@nodes.uniq.length}
#{@debug.inspect} 
#{values.inspect} )
  end
  def banner(s)
    @banner = s
  end
  def initialize(undirected)
    if undirected then
        DotEdge.undirected()
        @graph = 'graph'
    else
       @graph = 'digraph'
    end
    @debug = Array.new
    @nodes = Array.new
    @edges = Set.new
    @root = nil
    @banner = nil
    DotShape.build_flyweights()
  end
  def segment(edge_label, node1, node2)
      node(node1)
      node(node2)
      edge(edge_label,node1,node2) 
  end
  def root(n)
    @root=n
    node(n)
  end
  def format_root
    %Q(root=#{@root.identity};) if @root
  end
  def node(n)
    unless @nodes.member?(n)
        @nodes <<  n
    end
  end
  def edge(l,n1,n2)
      @edges << DotEdge.new(l,n1,n2)
  end
  def find_node(identity)
      node = @nodes[identity]
      raise Exception.new("No node found for #{identity}") if node.nil?
      node
  end
  
  def format_nodes
    @nodes.uniq.map {|node|
      %Q(#{node} ;//node)
  }.join("\n")
  end
  def format_edges
    @edges.map{|edge|
      %Q( #{edge}; //edge)
    }.join("\n")
  end
  def to_s
  %Q(#{banner}
   #{@graph} {
   graph [colorscheme="paired12", model="subset", size="8,11"] //, overlap=false] 
   node  [colorscheme="paired12", fontsize=8, nodesep=3.0, sytle="filled"]  // ranksep 
   edge  [colorscheme="paired12", fontcolor=blue, weight=0.5, color="//2"]
   #{format_root}
   #{format_nodes}
   #{format_edges}
  })
  end

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
