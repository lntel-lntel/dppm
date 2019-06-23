module DPPM::CLI::App
  extend self

  def query(prefix, group, application, path, **args) : String
    pkg_file = Prefix.new(prefix, group: group).new_app(application).pkg_file
    CLI.query(pkg_file.any, path).to_pretty_con
  end

  def delete(no_confirm, prefix, group, application, keep_user_group, preserve_database, **args)
    Prefix.new(prefix, group: group).new_app(application).delete !no_confirm, keep_user_group, preserve_database do
      CLI.confirm_prompt
    end
  end

  def upgrade(
    no_confirm,
    config,
    prefix,
    source_name,
    source_path,
    group,
    application,
    contained,
    custom_vars = Array(String).new,
    version = nil,
    tag = nil,
    **args
  )
    Log.info "initializing", "upgrade"
    vars = vars_parser custom_vars

    # Update cache
    root_prefix = Prefix.new prefix, group: group, source_name: source_name, source_path: source_path
    root_prefix.check
    if config
      root_prefix.dppm_config = Prefix::Config.new File.read config
    end
    root_prefix.update

    # Create task
    app = Prefix.new(prefix, group: group).new_app application
    app.upgrade(
      tag,
      version,
      vars: vars,
      shared: !contained,
      confirmation: !no_confirm
    ) do
      no_confirm || CLI.confirm_prompt
    end
    app
  end

  def add(
    no_confirm,
    config,
    prefix,
    source_name,
    source_path,
    group,
    application,
    contained,
    noservice,
    socket,
    custom_vars = Array(String).new,
    version = nil,
    tag = nil,
    name = nil,
    database = nil,
    url = nil,
    web_server = nil,
    debug = nil
  )
    Log.info "initializing", "add"
    vars = vars_parser custom_vars

    # Update cache
    root_prefix = Prefix.new prefix, group: group, source_name: source_name, source_path: source_path
    root_prefix.check
    if config
      root_prefix.dppm_config = Prefix::Config.new File.read config
    end
    root_prefix.update

    # Create task
    pkg = root_prefix.new_pkg application, version, tag
    app = pkg.new_app name
    app.add(
      vars: vars,
      shared: !contained,
      add_service: !noservice,
      socket: socket,
      database: database,
      url: url,
      web_server: web_server,
      confirmation: !no_confirm
    ) do
      no_confirm || CLI.confirm_prompt
    end
    app
  end

  def vars_parser(custom_vars : Array(String)) : Hash(String, String)
    vars = Hash(String, String).new
    custom_vars.each do |arg|
      case arg
      when .includes? '='
        key, value = arg.split '=', 2
        raise "only `a-z`, `A-Z`, `0-9` and `_` are allowed as variable name: " + arg if !Utils.ascii_alphanumeric_underscore? key
        vars[key] = value
      else
        raise "invalid variable: #{arg}"
      end
    end
    vars
  end

  def version(prefix, group, application, **args) : String
    Prefix.new(prefix, group: group).new_app(application).pkg.version
  end

  def exec(prefix, group, application, **args)
    app = Prefix.new(prefix, group: group).new_app application

    env_vars = app.pkg_file.env || Hash(String, String).new
    env_vars["PATH"] = app.path_env_var

    exec_start = app.exec["start"]
    Log.info "executing command", exec_start

    if port = app.get_config("port")
      Log.info "listening on port", port.to_s
    end
    Exec.run cmd: exec_start,
      env: env_vars,
      output: Log.output,
      error: Log.error,
      chdir: app.path.to_s, &.wait
  end

  def config_get(prefix, group, nopkg : Bool, application, path, **args)
    app = Prefix.new(prefix, group: group).new_app application
    if nopkg
      if nopkg && path == "."
        Log.output.puts app.config!.data
      else
        Log.output.puts app.config!.get path
      end
    elsif path == "."
      app.each_config_key do |key|
        Log.output << key << ": " << app.get_config(key) << '\n'
      end
    else
      Log.output.puts app.get_config path
    end
  end

  def config_set(prefix, group, nopkg : Bool, application, path, value, **args)
    app = Prefix.new(prefix, group: group).new_app application
    if nopkg
      app.config!.set path, value
    else
      app.set_config path, value
    end
    app.write_configs
  end

  def config_del(prefix, group, nopkg : Bool, application, path, **args)
    app = Prefix.new(prefix, group: group).new_app application
    if nopkg
      app.config!.del path
    else
      app.del_config path
    end
    app.write_configs
  end

  def self.logs(prefix : String, group : String, log_names : Array(String), lines : String?, follow : Bool, application : String, **args, &block : String ->)
    app = Prefix.new(prefix, group: group).new_app application
    if log_names.empty?
      Log.output << "LOG NAMES\n"
      app.each_log_file do |log_file|
        Log.output << log_file.rchop(".log") << '\n'
      end
    else
      channel = Channel(String).new
      log_names.each do |log_name|
        spawn do
          app.get_logs log_name + ".log", follow, lines.try(&.to_i) do |line|
            channel.send line
          end
        end
      end
      if follow
        while true
          yield channel.receive
        end
      else
        log_names.size.times do
          yield channel.receive
        end
      end
    end
  end
end
