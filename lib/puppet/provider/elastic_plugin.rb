require 'uri'
require 'puppet_x/elastic/es_versioning'
require 'puppet_x/elastic/plugin_name'

class Puppet::Provider::ElasticPlugin < Puppet::Provider
  attr_accessor :command_arguments, :homedir, :plugin_dir

  PROP_FILE = 'plugin-descriptor.properties'.freeze

  def self.homedir
    @homedir ||= case Facter.value('osfamily')
                 when 'OpenBSD'
                   '/usr/local/elasticsearch'
                 else
                   '/usr/share/elasticsearch'
                 end
  end

  def self.plugin_dir
    @plugin_dir ||= File.join(homedir, 'plugins')
  end

  def self.fetch_plugins
    return [] unless File.directory? plugin_dir

    Dir.entries(plugin_dir).select do |entry|
      File.directory?(File.join(plugin_dir, entry)) and \
        File.exist?(File.join(plugin_dir, entry, PROP_FILE))
    end.map do |plugin|
      Hash[
        IO.readlines(
          File.join(plugin_dir, plugin, PROP_FILE)
        ).map(&:strip).select do |line|
          !line.empty? and !line.start_with? '#'
        end.map do |line|
          line.split '='
        end
      ]
    end.map do |properties|
      {
        :name => properties['name'],
        :ensure => :present,
        :provider => name,
        :version => properties['version']
      }
    end
  end

  def self.instances
    fetch_plugins.map do |plugin|
      new plugin
    end
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  def install1x
    if !@resource[:url].nil?
      [
        Puppet_X::Elastic.plugin_name(@resource[:name]),
        '--url',
        @resource[:url]
      ]
    elsif !@resource[:source].nil?
      [
        Puppet_X::Elastic.plugin_name(@resource[:name]),
        '--url',
        "file://#{@resource[:source]}"
      ]
    else
      [
        @resource[:name]
      ]
    end
  end

  def install2x
    if !@resource[:url].nil?
      [
        @resource[:url]
      ]
    elsif !@resource[:source].nil?
      [
        "file://#{@resource[:source]}"
      ]
    else
      [
        @resource[:name]
      ]
    end
  end

  def proxy_args(url)
    parsed = URI(url)
    %w(http https).map do |schema|
      [:host, :port, :user, :password].map do |param|
        option = parsed.send(param)
        if !option.nil?
          "-D#{schema}.proxy#{param.to_s.capitalize}=#{option}"
        end
      end
    end.flatten.compact
  end

  def flush
    case @property_flush[:ensure]
    when :present
      commands = []
      if is2x?
        commands << "-Des.path.conf=#{self.class.homedir}"
        commands += proxy_args(@resource[:proxy]) if @resource[:proxy]
      end
      commands << 'install'
      commands << '--batch' if batch_capable?
      commands += is1x? ? install1x : install2x
      debug("Commands: #{commands.inspect}")

      retry_count = 3
      retry_times = 0
      begin
        with_environment do
          plugin(commands)
        end
      rescue Puppet::ExecutionFailure => e
        retry_times += 1
        debug("Failed to install plugin. Retrying... #{retry_times} of #{retry_count}")
        sleep 2
        retry if retry_times < retry_count
        raise "Failed to install plugin. Received error: #{e.inspect}"
      end
    when :absent
      with_environment do
        plugin(['remove', @resource[:name]])
      end
    end
  end

  def es_version
    Puppet_X::Elastic::EsVersioning.version(
      resource[:elasticsearch_package_name], resource.catalog
    )
  end

  def is1x?
    Puppet::Util::Package.versioncmp(es_version, '2.0.0') < 0
  end

  def is2x?
    (Puppet::Util::Package.versioncmp(es_version, '2.0.0') >= 0) && (Puppet::Util::Package.versioncmp(es_version, '3.0.0') < 0)
  end

  def batch_capable?
    Puppet::Util::Package.versioncmp(es_version, '2.2.0') >= 0
  end

  def plugin_version(plugin_name)
    _vendor, _plugin, version = plugin_name.split('/')
    return es_version if is2x? && version.nil?
    return version.scan(/\d+\.\d+\.\d+(?:\-\S+)?/).first unless version.nil?
    return false
  end

  # Run a command wrapped in necessary env vars
  def with_environment(&block)
    env_vars = {
      'ES_JAVA_OPTS' => [],
    }
    saved_vars = {}

    unless is2x?
      env_vars['ES_JAVA_OPTS'] << "-Des.path.conf=#{self.class.homedir}"
      if @resource[:proxy]
        env_vars['ES_JAVA_OPTS'] += proxy_args(@resource[:proxy])
      end
    end

    env_vars['ES_JAVA_OPTS'] = env_vars['ES_JAVA_OPTS'].join(' ')

    env_vars.each do |env_var, value|
      saved_vars[env_var] = ENV[env_var]
      ENV[env_var] = value
    end

    ret = block.call

    saved_vars.each do |env_var, value|
      ENV[env_var] = value
    end

    ret
  end

  def create
    @property_flush[:ensure] = :present
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def destroy
    @property_flush[:ensure] = :absent
  end
end
