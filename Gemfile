# frozen_string_literal: true

# This Gemfile is for tests inside this repo.
# The `build-tools` directory has its own Gemfile for the build tools.

# Install with: bundle install
source 'https://rubygems.org'

ruby file: '.ruby-version'

group :development, :test do
  # Testing framework
  gem 'rspec'
  # Browser-based testing hooks
  gem 'capybara'
  gem 'capybara-screenshot'
  gem 'selenium-webdriver'
  gem 'webdrivers'
  # Accessibility testing tools
  gem 'axe-core-capybara'
  gem 'axe-core-rspec'
  # Testing supports
  gem 'nokogiri'
  gem 'rack', '~> 3'
  gem 'rackup'
  gem 'webrick'
end
