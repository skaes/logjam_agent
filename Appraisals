appraisals = []
appraisals << "6.0.6.1" if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.1.0")
appraisals << "6.1.7.10"
appraisals << "7.0.8.6"
appraisals << "7.1.5"

if Gem::Version.new(RUBY_VERSION) > Gem::Version.new("3.1.0")
  appraisals << "7.2.2"
end

if Gem::Version.new(RUBY_VERSION) > Gem::Version.new("3.2.0")
  appraisals << "8.0.0"
end

appraisals.each do |rails_version|
  appraise "rails-#{rails_version}" do
    gem "rails", rails_version
    if rails_version < "8.0.0"
      gem "sqlite3", "~> 1.7"
    else
      gem "sqlite3", "~> 2.1"
    end
    gem "sprockets"
    gem "sass-rails"
    gem "uglifier"
    gem "nokogiri"
  end
end
