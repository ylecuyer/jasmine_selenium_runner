require 'spec_helper'
require 'tmpdir'
require 'jasmine'
require 'net/http'

describe Jasmine::Runners::Selenium do
  let(:file_helper) { FileHelper.new }
  it "permits rake jasmine:ci task to be run using Selenium" do
    project_root = File.expand_path(File.join(__FILE__, '..', '..'))
    Dir.mktmpdir do |dir|
      begin
        Dir.chdir dir
        File.open(File.join(dir, 'Gemfile'), 'w') do |file|
          file.write <<-GEMFILE
source 'https://rubygems.org'
gem 'jasmine_selenium_runner', :path => '#{project_root}'
gem 'jasmine', :git => 'https://github.com/pivotal/jasmine-gem.git'
GEMFILE
        end
        Bundler.with_clean_env do
          `bundle`
          `bundle exec jasmine init`
          FileUtils.cp(File.join(project_root, 'spec', 'fixtures', 'is_in_firefox_spec.js'), File.join(dir, 'spec', 'javascripts'))
          ci_output = `bundle exec rake -E "require 'jasmine_selenium_runner'" --trace jasmine:ci`
          ci_output.should =~ (/[1-9][0-9]* specs, 0 failures/)
        end
      ensure
        Dir.chdir project_root
      end
    end
  end

  it "permits rake jasmine:ci task to be run using Sauce", :sauce => true do
    project_root = File.expand_path(File.join(__FILE__, '..', '..'))
    Dir.mktmpdir do |dir|
      begin
        Dir.chdir dir
        File.open(File.join(dir, 'Gemfile'), 'w') do |file|
          file.write <<-GEMFILE
source 'https://rubygems.org'
gem 'jasmine_selenium_runner', :path => '#{project_root}'
gem 'jasmine', :git => 'https://github.com/pivotal/jasmine-gem.git'
GEMFILE
        end
        Bundler.with_clean_env do
          `bundle`
          `bundle exec jasmine init`
        File.open(File.join(dir, 'spec', 'javascripts', 'support', 'jasmine_selenium_runner.yml'), 'w') do |file|
          file.write <<-GEMFILE
---
use_sauce: true
browser: "internet explorer"
result_batch_size: 25
sauce:
  name: "jasmine_selenium_runner <%= Time.now.to_s %>"
  username: #{ENV['SAUCE_USERNAME']}
  access_key: #{ENV['SAUCE_ACCESS_KEY']}
  build: <%= ENV['TRAVIS_BUILD_NUMBER'] || 'Ran locally' %>
  tags:
    - <%= ENV['TRAVIS_RUBY_VERSION'] || RUBY_VERSION %>
    - CI
  tunnel_identifier: <%= ENV['TRAVIS_JOB_NUMBER'] %>
  os: "Windows 8"
  browser_version: 10
GEMFILE
        end
          FileUtils.cp(File.join(project_root, 'spec', 'fixtures', 'is_in_ie_spec.js'), File.join(dir, 'spec', 'javascripts'))

          test_start_time = Time.now.to_i
          uri = URI.parse "https://saucelabs.com/rest/v1/#{ENV['SAUCE_USERNAME']}/jobs?from=#{test_start_time}"
          job_list_request = Net::HTTP::Get.new(uri)
          job_list_request.basic_auth(ENV['SAUCE_USERNAME'], ENV['SAUCE_ACCESS_KEY'])
          before = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
            http.request(job_list_request)
          end
          JSON.parse(before.body).should == []
          ci_output = %x{bundle exec rake -E "require 'jasmine_selenium_runner'" --trace jasmine:ci}
          ci_output.should =~ (/[1-9][0-9]* specs, 0 failures/)
          after = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
            http.request(job_list_request)
          end
          JSON.parse(after.body).should_not be_empty
        end
      ensure
        Dir.chdir project_root
      end
    end
  end
end

