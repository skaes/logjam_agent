appraisals = []
appraisals << "6.0.6.1" if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.1.0")
appraisals << "6.1.7.8"
appraisals << "7.0.8.4"
appraisals << "7.1.3.4"

appraisals.each do |rails_version|
  appraise "rails-#{rails_version}" do
    gem "rails", rails_version
    gem "sprockets"
    gem "sass-rails"
    gem "uglifier"
    gem "nokogiri"
  end
end
