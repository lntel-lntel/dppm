require "mysql"

struct Database::MySQL
  include Base

  def initialize(@uri : URI, @user : String)
    @uri.scheme = "mysql"
  end

  private def database_exists?(db : DB::Database, database : String)
    db.unprepared("SHOW DATABASES LIKE '#{@user}'").query do |rs|
      rs.each do
        return true
      end
    end
    false
  rescue ex : DB::Error
    raise "can't connect to the database: #{@uri}"
  end

  def check_connection
    DB.open @uri { }
  rescue ex : DB::Error
    raise "can't connect to the database: #{@uri}"
  end

  def check_user
    DB.open @uri do |db|
      db.unprepared("SELECT User FROM mysql.user WHERE User = '#{@user}'").query do |rs|
        database_exists_error if database_exists? db, @user
        rs.each do
          users_exists_error
        end
      end
    end
  rescue ex : DB::Error
    raise "can't connect to the database: #{@uri}"
  end

  def set_root_password : String
    password = Database.gen_password
    DB.open @uri do |db|
      db.unprepared("ALTER USER 'root'@'%' IDENTIFIED BY '#{password}'").exec
      db.unprepared("FLUSH PRIVILEGES").exec
    end
    @uri.password = password
  rescue ex : DB::Error
    raise "can't connect to the database: #{@uri}"
  end

  def create(password : String)
    DB.open @uri do |db|
      db.unprepared("CREATE DATABASE #{@user}").exec
      db.unprepared("GRANT USAGE ON *.* TO '#{@user}'@'#{@uri.hostname}' IDENTIFIED BY '#{password}'").exec
      db.unprepared("GRANT ALL PRIVILEGES ON #{@user}.* TO '#{@user}'@'#{@uri.hostname}'").exec
      db.unprepared("FLUSH PRIVILEGES").exec
    rescue ex
      delete
      raise ex
    end
  end

  def clean
    DB.open @uri do |db|
      db.unprepared("SELECT user, host FROM mysql.user").query do |rs|
        rs.each do
          user = rs.read String
          hostname = rs.read String
          if user.starts_with?('_') && !database_exists? db, user
            db.unprepared("DROP USER '#{user}'@'#{hostname}'").exec
          end
        end
      end
      db.unprepared("FLUSH PRIVILEGES").exec
    end
  rescue ex : DB::Error
    raise "can't connect to the database: #{@uri}"
  end

  def delete
    DB.open @uri do |db|
      db.unprepared("DROP DATABASE IF EXISTS #{@user}").exec
    end
  rescue ex : DB::Error
    raise "can't connect to the database: #{@uri}"
  end
end
