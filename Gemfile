Warning[:deprecated] = false if RUBY_VERSION =~ /\A2.7/

source "https://rubygems.org"

# Specify your gem's dependencies in logjam_agent.gemspec
gemspec

gem "rails"
gem "sqlite3"
gem "sprockets"
gem 'sass-rails'
gem 'uglifier'
gem "nokogiri"

# Use patched appraisal gem until it is fixed upstream.
gem "appraisal", git: "https://github.com/toy/appraisal.git", ref: "55334f67f96448c2209648a20ccaeb3800a6ab0f"
