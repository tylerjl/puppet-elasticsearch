require 'spec_helper'

describe 'elasticsearch', :type => 'class' do
  on_supported_os(
    :hardwaremodels => ['x86_64'],
    :supported_os => [
      {
        'operatingsystem' => 'CentOS',
        'operatingsystemrelease' => ['6']
      }
    ]
  ).each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts.merge(
        :scenario => '',
        :common => ''
      ) }

      describe "security logging configuration file for x-pack" do
        {
          'content' => {
            :manifest => "one = two\nfoo = bar\n",
            :value => "one = two\nfoo = bar\n"
          },
          'source' => {
            :manifest => '/foo/bar.properties',
            :value => '/foo/bar.properties'
          }
        }.each_pair do |param_type, params|
          context "parameter #{param_type}" do
            let(:params) do
              {
                :security_plugin => 'x-pack',
                "security_logging_#{param_type}" => params[:manifest]
              }
            end

            it { should contain_file("/etc/elasticsearch/x-pack")
                .with_ensure('directory')}

            case param_type
            when 'source'
              it 'sets the source for the file resource' do
                should contain_file("/etc/elasticsearch/x-pack/log4j2.properties")
                  .with_source(params[:value])
              end
            when 'content'
              it 'sets logging file yaml content' do
                should contain_file("/etc/elasticsearch/x-pack/log4j2.properties")
                  .with_content(params[:value])
              end
            end
          end
        end
      end
    end
  end
end
