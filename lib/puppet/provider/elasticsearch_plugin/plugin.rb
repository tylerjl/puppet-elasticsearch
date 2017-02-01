require 'puppet/provider/elastic_plugin'

Puppet::Type.type(:elasticsearch_plugin).provide(
  :plugin,
  :parent => Puppet::Provider::ElasticPlugin
) do
  desc 'Pre-5.x provider for Elasticsearch bin/plugin command operations.'

  mk_resource_methods

  commands :plugin => "#{homedir}/bin/plugin"
  commands :es => "#{homedir}/bin/elasticsearch"

  if Facter.value('osfamily') == 'OpenBSD'
    commands :javapathhelper => '/usr/local/bin/javaPathHelper'
  end
end
