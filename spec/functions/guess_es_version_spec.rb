require 'spec_helper'

describe 'guess_es_version' do

  describe 'exception handling' do
    it { is_expected.to run.with_params().and_raise_error(
      Puppet::ParseError, /wrong number of arguments/i
    ) }
  end

  describe 'unguessable arguments' do
    it { is_expected.to run.with_params(nil)
      .and_raise_error Puppet::ParseError }

    it { is_expected.to run.with_params('foobar', 'http://artifacts.elastic.co')
      .and_raise_error Puppet::ParseError }

    it { is_expected.to run.with_params('')
      .and_raise_error Puppet::ParseError }
  end

  {
    'typical versions' => Hash[*(
      ['0.90.1', '1.7', '2.4.1', '5.x'].map{|x|[x,x]}.flatten + ['1.1-2', '1.1']
    )],
    'package urls' => {
      'https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-1.4.2.deb' => '1.4.2',
      'http://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-1.3.1.noarch.rpm' => '1.3.1',
      'https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-1.4.2-1.deb' => '1.4.2',
      'http://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-1.3.1-1.noarch.rpm' => '1.3.1',
      'puppet:///path/to/elasticsearch-2.4.1.deb' => '2.4.1',
      'file:/path/to/elasticsearch-5.0.0.deb' => '5.0.0',
      '/path/0.0/to/elasticsearch-2.4.1.deb' => '2.4.1',
      '/path/to/elasticsearch-3-2.4.1.deb' => '2.4.1',
      '/path/to/elasticsearch-2.4.1-3.deb' => '2.4.1',
      '/path/to/elasticsearch-5.0.0-3.rpm' => '5.0.0',
      '/2.x/to/elasticsearch-5.0.0.deb' => '5.0.0'
    }
  }.each do |test_type, versions|
    describe test_type do
      versions.each do |pre_parsed, version|
        it { is_expected.to run.with_params(pre_parsed)
          .and_return(version) }

        it { is_expected.to run.with_params(nil, pre_parsed)
          .and_return(version) }

        it { is_expected.to run.with_params(pre_parsed, nil)
          .and_return(version) }

        it { is_expected.to run.with_params(pre_parsed, '1.0.0')
          .and_return(version) }

        it { is_expected.to run.with_params('1.0.0', pre_parsed)
          .and_return('1.0.0') }
      end
    end
  end
end
