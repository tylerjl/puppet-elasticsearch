require 'rubygems'
require 'puppetlabs_spec_helper/rake_tasks'
require 'net/http'
require 'uri'
require 'fileutils'
require 'rspec/core/rake_task'

# Determine whether we can use some future parse specific
# functionality (e.g. puppet-strings)
puppet_version = ENV['PUPPET_VERSION'] || '~> 3.8.0'
future = Gem::Version.new(puppet_version.split.last) >= Gem::Version.new('3.7.0')

if future
  require 'puppet-strings/rake_tasks'
  require 'puppet-strings/rake_tasks/generate'
else
  require 'puppet-doc-lint/rake_task'
end

module TempFixForRakeLastComment
  def last_comment
    last_description
  end
end
Rake::Application.send :include, TempFixForRakeLastComment

exclude_paths = [
  "pkg/**/*",
  "spec/**/*"
]

require 'puppet-lint/tasks/puppet-lint'
require 'puppet-syntax/tasks/puppet-syntax'

if future
  PuppetStrings::RakeTasks::Generate.new(:documentation) do |task|
    # Disable strings.json output
    task.options = {:list_undoc => true}
  end
else
  desc 'Run code documentation tests'
  task :documentation do
    testfiles = FileList['**/*.pp'].exclude(exclude_paths)
    runner = PuppetDocLint::Runner.new
    results = runner.run(testfiles)
    results.each { |result| result.result_report }
  end
end

PuppetSyntax.exclude_paths = exclude_paths
PuppetSyntax.future_parser = true if ENV['FUTURE_PARSER'] == 'true'

[
  '80chars',
  'class_inherits_from_params_class',
  'class_parameter_defaults',
  'documentation',
  'single_quote_string_with_variables'
].each do |check|
  PuppetLint.configuration.send("disable_#{check}")
end

PuppetLint.configuration.ignore_paths = exclude_paths
PuppetLint.configuration.log_format = "%{path}:%{linenumber}:%{check}:%{KIND}:%{message}"


RSpec::Core::RakeTask.new(:spec_verbose) do |t|
  t.pattern = 'spec/{classes,defines,unit,functions,templates}/**/*_spec.rb'
  t.rspec_opts = [
    '--format documentation',
    '--require "ci/reporter/rspec"',
    '--format CI::Reporter::RSpecFormatter',
    '--color'
  ]
end
task :spec_verbose => :spec_prep

RSpec::Core::RakeTask.new(:spec_unit) do |t|
  t.pattern = 'spec/{classes,defines,unit,functions,templates}/**/*_spec.rb'
  t.rspec_opts = ['--color']
end
task :spec_unit => :spec_prep

task :beaker => [:spec_prep, 'artifacts:prep']

desc 'Run integration tests'
RSpec::Core::RakeTask.new('beaker:integration') do |c|
  c.pattern = 'spec/integration/integration*.rb'
end
task 'beaker:integration' => [:spec_prep, 'artifacts:prep']

desc 'Run acceptance tests'
RSpec::Core::RakeTask.new('beaker:acceptance') do |c|
  c.pattern = 'spec/acceptance/0*_spec.rb'
end
task 'beaker:acceptance' => [:spec_prep, 'artifacts:prep']


if not ENV['BEAKER_IS_PE'].nil? and ENV['BEAKER_IS_PE'] == 'true'
  task :beaker => 'artifacts:pe'
  task 'beaker:integration' => 'artifacts:pe'
  task 'beaker:acceptance' => 'artifacts:pe'
end


namespace :artifacts do
  desc "Fetch artifacts for tests"
  task :prep do
    fetch_archives({
    'https://github.com/lmenezes/elasticsearch-kopf/archive/v2.1.1.zip' => 'elasticsearch-kopf.zip',
    'https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-1.3.1.deb' => 'elasticsearch-1.3.1.deb',
    'https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-1.1.0.deb' => 'elasticsearch-1.1.0.deb',
    'https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-1.3.1.noarch.rpm' => 'elasticsearch-1.3.1.noarch.rpm',
    'https://github.com/lukas-vlcek/bigdesk/zipball/v2.4.0' => 'elasticsearch-bigdesk.zip',
  })
  end

  desc "Retrieve PE archives"
  task :pe do
    if not ENV['BEAKER_set'].nil?
      case ENV['BEAKER_set']
      when /centos-(\d)/
        distro = 'el'
        version = $1
        arch = "x86_64"
      when /(debian)-(\d)/
        distro = $1
        version = $2
        arch = "amd64"
      when /(sles)-(\d+)/
        distro = $1
        version = $2
        arch = "x86_64"
      when /(ubuntu)-server-(12|14)/
        distro = $1
        version = "#{$2}.04"
        arch = "amd64"
      else
        puts "Could not find PE version for #{ENV['BEAKER_set']}"
        return
      end
      pe_version = ENV['BEAKER_PE_VER']
      file = "puppet-enterprise-#{pe_version}-#{distro}-#{version}-#{arch}.tar.gz"
      fetch_archives({
        "https://s3.amazonaws.com/pe-builds/released/#{pe_version}/#{file}" => file
      })
    else
      puts "No nodeset set, skipping PE artifact retrieval"
    end
  end

  desc "Purge fetched artifacts"
  task :clean do
    FileUtils.rm_rf(Dir.glob('spec/fixtures/artifacts/*'))
  end
end

def fetch_archives archives
  archives.each do |url, fp|
    fp.replace "spec/fixtures/artifacts/#{fp}"
    if File.exists? fp
      if fp.end_with? 'tar.gz' and \
          not system("tar -tzf #{fp} &>/dev/null")
        puts "Archive #{fp} corrupt, re-fetching..."
        File.delete fp
      else
        puts "Already retrieved intact archive #{fp}..."
        next
      end
    end
    get url, fp
  end
end

def get url, file_path
  puts "Fetching #{url}..."
  found = false
  until found
    uri = URI::parse(url)
    conn = Net::HTTP.new(uri.host, uri.port)
    conn.use_ssl = true
    res = conn.get(uri.path)
    if res.header['location']
      url = res.header['location']
    else
      found = true
    end
  end
  File.open(file_path, 'w+') { |fh| fh.write res.body }
end
