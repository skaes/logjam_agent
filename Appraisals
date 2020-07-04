[
  "5.2.4.3",
  "6.0.3.2"
].each do |rails_version|
  appraise "rails-#{rails_version}" do
    gem "rails", rails_version
    gem "sqlite3"
    gem "sprockets"
    gem 'sass-rails'
    gem 'uglifier'
    gem "nokogiri"
  end
end
