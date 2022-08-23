appraisals = []
appraisals << "5.2.7" if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.0.0")
appraisals << "6.0.5.1" if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.1.0")
appraisals << "6.1.6.1"
appraisals << "7.0.3.1" if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("2.7.0")

appraisals.each do |rails_version|
  appraise "rails-#{rails_version}" do
    gem "rails", rails_version
    gem "sqlite3"
    gem "sprockets"
    gem 'sass-rails'
    gem 'uglifier'
    gem "nokogiri"
  end
end
