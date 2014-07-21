# require 'active_record'
# 
module PostgresAccess
  class Parse
    METHOD_SOURCE = [:pgenv, :url, :heroku, :database_url]
    attr_reader  :method
    attr_reader  :value
     
    def initialize(args='DATABASE_URL') 
      @value = nil
      select_method(args)
      unless METHOD_SOURCE.member?(self.method) then
         raise Exception.new("Failed to find correct methods(#{self.method}, #{value},#{args})")
      end
    end
    def select_method(args)
        selector = args.strip
        if selector =~ /^pgenv/i
            @method = :pgenv
            @value = _pg_env_hash()
        elsif selector =~ /^heroku:(.+)$/
            @method = :heroku
            @value  = heroku_config($1)
        elsif selector =~ /^database_url/i
            use_database_url
        elsif selector =~ %r(^postgres://)i
            @method = :url
            @value = selector
        elsif selector =~ /^postgres$/i
            use_database_url
        else
           raise Exception.new("Failed to match: (#{args})")
        end
    end
    def connect
      @value
    end
    def use_database_url
      @method = :database_url
      @value = ENV['DATABASE_URL']
    end
    def heroku_config(appname)
        %x(heroku config:get DATABASE_URL -a #{appname} ).strip
    end
    def _pg_env_hash
      h = Hash.new
      h[:adapter]  = "postgresql"
      h[:username] = [ENV["PGUSER"], ENV["USER"]].compact.first
      h[:password] = ENV["PGPASSWORD"] 
      h[:database] = ENV["PGDATABASE"]
      h[:port]     = ENV["PGPORT"]
      h[:host]     = ENV["PGHOST"]
      h.delete_if{|k,v| v.nil? }
      h
    end
  end
end

#require 'active_record'
#require 'Getopt/Declare'

#$DEBUG = false
# -c pgenv
# -c postgres
# -c heroku:app
# -c 
#-c DATABASE_URL
#DATABASE_URL
#or
#PGDATABASE
#PGPORT
#PGHOST
#PGUSERNAME
#PGPASSWORD
#
# herokuo
# heroku config:set DATABASE_URL=`heroku config:get DATABASE_URL -a source-app`


# require 'active_record'
#DESKTOP ={:adapter => 'postgresql', :username=>'slaught', 
#          :port=>5432, :database=>'ci-no'}
#ActiveRecord::Base.establish_connection(
#  :adapter  => "mysql",
#  :host     => "localhost",
#  :username => "myuser",
#  :password => "mypass",
#  :database => "somedatabase"
#)
#
#def main()
#    STDERR.puts @args.inspect if $DEBUG
#    if @args['-c'] == 'chad' then
#        connection_url = DESKTOP
#    else
#        connection_url = @args['-c']
#    end
#    ActiveRecord::Base.establish_connection(connection_url)
##
