require 'postgres_access'

require 'test/unit'

class PostgresAccessTest < Test::Unit::TestCase

  def setup()
    @backup = ENV.to_hash 
    @defaults = {"DATABASE_URL" => "test_database_url",
      "PGUSER" => 'pguser', "USER" => 'osuser',
      "PGPASSWORD" => 'password',
      "PGDATABASE" => 'database_name',
      "PGHOST" => 'database-host',
      "PGPORT" => '1234567890'
    }
    ENV.update(@defaults)
  end
  def teardown 
    ENV.replace(@backup)
  end
  def pick_heroku_app
# $ heroku apps
# === My Apps
# example
# example2
#
# === Collaborated Apps
# theirapp   other@owner.name
      apps = %x(heroku apps).split("\n")
      app = apps.map{|a| a if a.strip.length > 0 }.compact.last
      app.split.first
  end
  def test_heroku
    x = %x(which heroku).strip
    if File.exist?(x) then 
      app = pick_heroku_app
      assert app, 'No application was picked'
      p = PostgresAccess::Parse.new("heroku:"+app)
      assert p
      value = p.connect
      assert_match %r(^postgres://), value , 'no heroku url' 
    else
      skip "heroku testing as no cmdline client found" 
    end
  end
  def test_pgenv_with_no_port
      ENV["PGPORT"] = nil
      p = PostgresAccess::Parse.new('pgenv')
      assert p
      value = p.connect
      assert value.kind_of?(Hash), "is not a hash"
      assert_nil value[:port], "port is present"
      assert_equal 5, value.keys.length, "wrong number of keys"
  end
  def test_pgenv_with_no_host_or_port
      ENV["PGHOST"] = nil
      ENV["PGPORT"] = nil
      p = PostgresAccess::Parse.new('pgenv')
      assert p
      value = p.connect
      assert value.kind_of?(Hash), "is not a hash"
      assert_nil value[:host], "hostname is present"
      assert_nil value[:port], "port is present"
      assert_equal 4, value.keys.length, "wrong number of keys"
  end
  def test_pgenv_with_no_host
      ENV["PGHOST"] = nil
      p = PostgresAccess::Parse.new('pgenv')
      assert p
      value = p.connect
      assert value.kind_of?(Hash), "is not a hash"
      assert_nil value[:host], "hostname is present"
      assert_equal 5, value.keys.length, "wrong number of keys"
  end
  def test_url
      url = 'postgres://somethignelse:99432/asfasdf'
      p = PostgresAccess::Parse.new(url)
      assert p
      value = p.connect
      assert value.is_a?(String)
      assert_equal url, value, "url is not matching "
  end
  def test_postgres 
      p = PostgresAccess::Parse.new('postgres')
      assert p
      value = p.connect
      assert value.is_a?(String)
      assert_equal value, @defaults["DATABASE_URL"], "check value of 'postgres' selection"
  end
  def test_pgenv
      p = PostgresAccess::Parse.new('pgenvironment')
      assert p
      value = p.connect
      assert value.kind_of?(Hash), "is a hash"
      assert_equal value[:host], @defaults["PGHOST"], "hostname is wrong"
      assert_equal value.keys.length, 6, "Has all keys in hash"
  end
  def test_database_url
      p = PostgresAccess::Parse.new('DATABASE_URL')
      assert p
      assert_match p.connect, @defaults["DATABASE_URL"]
  end
  def test_default_no_args
      p = PostgresAccess::Parse.new
      assert p
      assert_match p.connect, @defaults["DATABASE_URL"]
  end
end

