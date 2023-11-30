require 'dotenv/load'
require 'faraday'

require 'debug'

CONFIG = {
  user_name: ENV['USER_NAME']
  user_agent_string: "#{ENV['USER_NAME']}_crawler_cli_v2",
  user_token: ENV['PERSONAL_ACCESS_TOKEN']
}

puts "Initializing Discogs Crawler V2 for #{CONFIG[:user_name]}."

puts 'Please input Seller name:'
print '>>> '
seller = gets.chomp
puts

puts 'Input (v) to browse Vinyl'
puts 'Input (c) to browse Cassettes'
puts 'Leave blank to browse all'
print '>>> '
format_filter = gets.chomp
puts

# get the seller inventory page by page, 100 items at a time
# load each page into memory
# filter results by format
# group filtered results by artist
# 1 group for vinyl
# 1 group for cassettes
# all of these are still in memory
# display summary results to user
# prompt user to browse filtered results by choosing format
# filtered results are displayed, sorted by artist ABC


response.pagination.pages
response.pagination.items

"https://api.discogs.com/users/lastvestige/inventory?&page=1&per_page=100"

"/lastvestige/inventory?format=Vinyl"
"/lastvestige/inventory?format=Cassette"
