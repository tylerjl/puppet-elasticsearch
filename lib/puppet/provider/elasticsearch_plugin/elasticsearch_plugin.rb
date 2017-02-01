require 'puppet/provider/elastic_plugin'

Puppet::Type.type(:elasticsearch_plugin).provide(
  :elasticsearch_plugin,
  :parent => Puppet::Provider::ElasticPlugin
) do
  desc <<-END
    Post-5.x provider for Elasticsearch bin/elasticsearch-plugin
    command operations.'
  END

  mk_resource_methods

  commands :plugin => "#{homedir}/bin/elasticsearch-plugin"
  commands :es => "#{homedir}/bin/elasticsearch"

  if Facter.value('osfamily') == 'OpenBSD'
    commands :javapathhelper => '/usr/local/bin/javaPathHelper'
  end
end
