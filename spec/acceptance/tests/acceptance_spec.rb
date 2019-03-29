require 'spec_helper_acceptance'
require 'helpers/acceptance/tests/basic_shared_examples.rb'
require 'helpers/acceptance/tests/template_shared_examples.rb'
require 'helpers/acceptance/tests/removal_shared_examples.rb'
require 'helpers/acceptance/tests/pipeline_shared_examples.rb'
require 'helpers/acceptance/tests/plugin_shared_examples.rb'
require 'helpers/acceptance/tests/snapshot_repository_shared_examples.rb'
require 'helpers/acceptance/tests/datadir_shared_examples.rb'
require 'helpers/acceptance/tests/package_url_shared_examples.rb'
require 'helpers/acceptance/tests/hiera_shared_examples.rb'
require 'helpers/acceptance/tests/usergroup_shared_examples.rb'
require 'helpers/acceptance/tests/security_shared_examples.rb'

describe "elasticsearch v#{v[:elasticsearch_full_version]} class" do
  es_01 = {
    'es-01' => {
      'config' => {
        'http.port' => 9200,
        'node.name' => 'elasticsearch001'
      }
    }
  }
  es_02 = {
    'es-02' => {
      'config' => {
        'http.port' => 9201,
        'node.name' => 'elasticsearch002'
      }
    }
  }
  instances = es_01.merge es_02

  let(:elastic_repo) { not v[:is_snapshot] }
  let(:manifest) do
    package = if not v[:is_snapshot]
                <<-MANIFEST
                  # Hard version set here due to plugin incompatibilities.
                  version => '#{v[:elasticsearch_full_version]}',
                MANIFEST
              else
                <<-MANIFEST
                  manage_repo => false,
                  package_url => '#{v[:snapshot_package]}',
                MANIFEST
              end

    <<-MANIFEST
      api_timeout => 60,
      config => {
        'cluster.name' => '#{v[:cluster_name]}',
        'http.bind_host' => '0.0.0.0',
      },
      oss => #{v[:oss]},
      jvm_options => [
        '-Xms128m',
        '-Xmx128m',
      ],
      #{package}
    MANIFEST
  end

  context 'instance testing with' do
    describe 'one' do
      include_examples('basic acceptance tests', es_01)
    end

    describe 'two' do
      include_examples('basic acceptance tests', instances)
    end

    describe 'one absent' do
      include_examples('basic acceptance tests', es_01.merge('es-02' => {}))
    end

    include_examples 'module removal', ['es-01']
  end

  include_examples('template operations', es_01, v[:template])

  include_examples('pipeline operations', es_01, v[:pipeline])

  unless v[:elasticsearch_plugins].empty?
    include_examples('plugin acceptance tests', v[:elasticsearch_plugins])
  end

  include_examples 'snapshot repository acceptance tests'

  include_examples 'datadir acceptance tests'

  # Skip this for snapshot testing, as we only have package files anyway.
  include_examples 'package_url acceptance tests' unless v[:is_snapshot]

  include_examples 'hiera acceptance tests', v[:elasticsearch_plugins]

  include_examples 'user/group acceptance tests'

  # Security-related tests.
  #
  # Skip OSS-only distributions since they do not bundle x-pack, and skip
  # snapshots since we they don't recognize prod licenses.
  include_examples 'security acceptance tests', instances unless v[:oss] or v[:is_snapshot]
end
