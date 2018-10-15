module Manager::Package::CLI
  extend self

  def clean(no_confirm, config, mirror, source, prefix)
    Log.info "initializing", "clean"
    task = Clean.new prefix
    if task.packages.empty?
      Log.info "No packages to clean", task.pkgdir
      exit
    end

    Log.info "clean", task.simulate
    task.run if no_confirm || Manager.cli_confirm
  end

  def delete(no_confirm, config, mirror, source, prefix, package, custom_vars)
    Log.info "initializing", "delete"
    task = Delete.new package, prefix

    Log.info "delete", task.simulate
    task.run if no_confirm || Manager.cli_confirm
  end

  def build(no_confirm, config, mirror, source, prefix, package, custom_vars)
    vars = Hash(String, String).new
    Log.info "initializing", "build"
    vars["package"] = package
    vars["prefix"] = prefix

    # configuration
    begin
      configuration = INI.parse(File.read config || CONFIG_FILE)

      vars["source"] = source || configuration["main"]["source"]
      vars["mirror"] = mirror || configuration["main"]["mirror"]
    rescue ex
      raise "configuraration error: #{ex}"
    end

    # Update cache
    Source::Cache.update vars["source"], prefix

    # Create task
    vars.merge! ::System::Host.vars
    task = Build.new vars
    Log.info "build", task.simulate
    task.run if no_confirm || Manager.cli_confirm
  end

  def self.query(prefix, config, mirror, source, no_confirm, package, path)
    Query.new(Path.new(prefix).package package).pkg path
  end
end
