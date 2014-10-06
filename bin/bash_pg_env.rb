#!/usr/bin/env ruby
require 'uri'

@url = ARGV.first
if @url.nil? then
    puts "#{$0} <database_url>"
    exit -1
end
u = URI.parse(@url)
u.port = 5432 if u.port.nil?
print %Q(# source into bash shell
export PGDATABASE='#{u.path[1..-1]}'
export PGUSER='#{u.user}'
export PGPORT='#{u.port}'
export PGHOST='#{u.host}'
export PGPASSWORD='#{u.password}'
)
