module Service::Config
  property user : String? = nil,
    group : String? = nil,
    directory : String? = nil,
    command : String? = nil,
    reload_signal : String? = nil,
    description : String? = nil,
    log_output : String? = nil,
    log_error : String? = nil,
    env_vars : Hash(String, String) = Hash(String, String).new,
    after : Array(String) = Array(String).new,
    before : Array(String) = Array(String).new,
    want : Array(String) = Array(String).new,
    umask : String? = "007",
    restart_delay : UInt32? = 9_u32

  macro included
  def initialize
  end

  def self.read(file : String) : Config
    if file && File.exists? file
      new File.read(file)
    else
      new
    end
  end
  end

  def parse_env_vars(env_vars : String)
    env_vars.rchop.split("\" ").each do |env|
      var, val = env.split("=\"")
      @env_vars[var] = val
    end
  rescue
    # the PATH is not set/corrupt - make a new one from what we have parsed
  end

  def build_env_vars : String
    String.build { |str| build_env_vars str }
  end

  def build_env_vars(io)
    start = true
    @env_vars.each do |variable, value|
      io << ' ' if !start
      io << variable << "=\"" << value << '"'
      start = false
    end
  end
end
