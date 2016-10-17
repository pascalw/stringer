require "rubygems"
require "bundler"

Bundler.require

require "./fever_api"
map "/fever" do
  run FeverAPI::Endpoint
end

require "./inoreader_api"
map "/inoreader/#{ENV['INOREADER_TOKEN']}" do
  run InoreaderAPI::Endpoint
end

require "./app"
run Stringer
