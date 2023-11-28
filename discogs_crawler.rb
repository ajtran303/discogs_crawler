require 'dotenv/load'
require 'discogs'

# supress warnings about setting conflicting keys
require 'hashie'
Hashie.logger = Logger.new(nil)

CONFIG = {
  user_agent_string: "#{ENV['USER_NAME']}_crawler_cli",
  user_token: ENV['PERSONAL_ACCESS_TOKEN']
}

puts "Initializing Discogs Crawler for #{ENV['USER_NAME']}."

@wrapper = Discogs::Wrapper.new(CONFIG[:user_agent_string], user_token: CONFIG[:user_token])

def fetch_shop_items(seller_name, page)
  @wrapper.get_user_inventory(seller_name, {page: page, per_page: 100, sort: 'artist', sort_order: 'asc'})
end

def group_shop_items_by_artist(shop_page_h)
  return if shop_page_h.listings.nil?

  shop_page_h.listings.reduce([]) do |acc, listing|
    current_artist = listing.release.artist
    artist_releases = {artist: current_artist, releases: 1}

    if acc.size.zero?
      acc << artist_releases
    elsif acc.last[:artist] == current_artist
      acc.last[:releases] += 1 
    else
      acc << artist_releases
    end
    
    acc
  end
end

def get_artist_releases(shop_page_h, artist)
  artist_releases = shop_page_h.listings.filter do |item|
    item.release.artist == artist
  end
  artist_releases.map do |item|
    "#{item.release.title} - #{item.price.value} #{item.price.currency} - #{item.uri}"
  end.sort
end

def fetch_page(seller_name, current_page, opt='next')
    page_number = opt == 'previous' ? current_page - 1 : current_page + 1
    puts
    puts "Fetching #{opt} page. Please wait."
    puts
    run_crawler(seller_name, page_number)
end

def run_crawler(seller_name, current_page_number, previous_page=nil)
  shop_page = !previous_page.nil? ? previous_page : fetch_shop_items(seller_name, current_page_number)
  artists = group_shop_items_by_artist(shop_page)

  if artists.nil?
    puts "That's the end of #{seller_name}'s inventory!"
    stop_crawler
  end

  puts "#{seller_name} has #{artists.length} Artist(s) on this Page (#{current_page_number}):"
  puts
  
  artists.each.with_index { |item, i| puts "#{i+1}: #{item[:artist]} - #{item[:releases]} releases" }
  puts
  
  puts "You are on Page #{current_page_number}"
  puts 'Input (a) to go to previous page' unless current_page_number == 1
  puts 'Input (z) to go to next page'
  puts "Input (number) to view an Artist's releases"
  puts 'Input any other key to exit'
  print '>>> '
  option = gets.chomp
  
  if option == 'a' && current_page_number != 1
    fetch_page(seller_name, current_page_number, 'previous')
  elsif option == 'z'
    fetch_page(seller_name, current_page_number)
  elsif option.to_i > 0
    selected_artist = artists[option.to_i - 1][:artist]
    releases = get_artist_releases(shop_page, selected_artist)
    puts
    puts "Viewing #{releases.size} release(s) by '#{selected_artist}' (Title - Price - Link):"
    puts
    releases.each do |release|
      puts release
    end

    puts
    puts "Input (a) to go back to Page #{current_page_number}"
    puts 'Input (z) to go to next Page'
    puts 'Input any other key to exit'
    print '>>> '
    navigation = gets.chomp
    
    if navigation == 'a'
      puts 
      run_crawler(seller_name, current_page_number, shop_page)
    elsif navigation == 'z'
      fetch_page(seller_name, current_page_number)
    else
      stop_crawler
    end

  else
    stop_crawler
  end
end

def stop_crawler
  puts
  puts 'Goodbye!'
  exit
end

puts 'Discogs Crawler initialized!'
puts

puts 'Please input Seller name: '
print '>>> '
seller = gets.chomp
puts

puts "Browse #{seller}'s shop from a specific page number? Input (number) or press (Return) to start from Page 1"
print '>>> '
starting_page = gets.chomp.to_i
starting_page = 1 if starting_page.zero?
puts

puts "Fetching #{seller} store inventory, starting from Page #{starting_page}. Please wait."
puts

run_crawler(seller, starting_page)