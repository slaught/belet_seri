require File.expand_path("../lib/postgres_access/version", __FILE__)

Gem::Specification.new do |gem|
  gem.name    = "postgres_access"
  gem.version = PostgresAccess::VERSION
  gem.date    = "2014-07-21"

  gem.summary = "Simplify acccess to Postgres databases for commandline apps"
  gem.description = "Simplify access to Postgres databases.
It supports several options: DATABASE_URL enviroment variable, 
PG* environment values, heroku toolbelt and selecting via application name,
and basic postgres schema URLs.
"

  gem.authors  = ['Chad Slaughter']
  gem.email    = 'chad.slaughter+gem@gmail.com'
  gem.homepage = 'http://github.com/slaught/belet-seri'

  gem.add_dependency('activerecord')

  # ensure the gem is built out of versioned files
  gem.files = [
	"postgres_access.gemspec",
	"lib/postgres_access.rb",
	"lib/postgres_access",
	"lib/postgres_access/parse.rb",
	"lib/postgres_access/version.rb",
	"test/postgres_access_test.rb",
  "README-postgres_access.md",
  "LICENSE",
]
end


