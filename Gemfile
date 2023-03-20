Warning[:deprecated] = false if RUBY_VERSION =~ /\A2.7/

source "https://rubygems.org"

# Specify your gem's dependencies in logjam_agent.gemspec
gemspec

gem "rails"
gem "sqlite3"
gem "sprockets"
gem "sass-rails"
gem "uglifier"
gem "nokogiri"
gem "rake"
gem "i18n"
gem "snappy"
gem "lz4-ruby"
gem "oj"
gem "byebug"
gem "minitest"
gem "mocha"
gem "sinatra", require: false
gem "sinatra-contrib", require: false
gem "rack-test"
gem "simplecov"

# Use patched appraisal gem until it is fixed upstream.
gem "appraisal", git: "https://github.com/thoughtbot/appraisal.git", ref: "0c855ae0da89fec74b4d1a01801c55b0e72496d4"
