require 'dotenv/load'
require 'faraday'
require 'json'
require 'uri'

CONFIG = {
  user_name: ENV['USER_NAME'],
  user_agent_string: "#{ENV['USER_NAME']}_crawler_cli_v2",
  user_token: ENV['PERSONAL_ACCESS_TOKEN']
}

puts "Initializing Discogs Crawler V2 for #{CONFIG[:user_name]}."

@client = Faraday.new(url: 'https://api.discogs.com') do |f|
  f.headers['User-Agent'] = CONFIG[:user_agent_string]
  f.headers['Authorization'] = "Discogs token=#{CONFIG[:user_token]}"
end

@page_cache = {}
@cache_mutex = Mutex.new
@total_pages = nil
@total_items = nil

def fetch_shop_items(seller_name, page)
  @cache_mutex.synchronize { return @page_cache[page] if @page_cache[page] }

  encoded_seller = URI.encode_www_form_component(seller_name)
  response = @client.get("/users/#{encoded_seller}/inventory", {
    page: page,
    per_page: 100,
    sort: 'artist',
    sort_order: 'asc'
  })

  if response.success?
    data = JSON.parse(response.body, object_class: OpenStruct)
    @cache_mutex.synchronize do
      @total_pages = data.pagination['pages']
      @total_items = data.pagination['items']
      @page_cache[page] = data
    end
    data
  else
    puts "Error fetching inventory: #{response.status}"
    nil
  end
end

def group_shop_items_by_artist(shop_page)
  return nil if shop_page.nil? || shop_page.listings.nil? || shop_page.listings.empty?

  shop_page.listings.reduce([]) do |acc, listing|
    current_artist = listing.release['artist']
    artist_releases = { artist: current_artist, releases: 1 }

    if acc.empty?
      acc << artist_releases
    elsif acc.last[:artist] == current_artist
      acc.last[:releases] += 1
    else
      acc << artist_releases
    end

    acc
  end
end

def get_artist_releases(shop_page, artist)
  artist_releases = shop_page.listings.filter do |item|
    item.release['artist'] == artist
  end

  artist_releases.map do |item|
    format = item.release['format'] || 'Unknown'
    "#{item.release['title']} [#{format}] - #{item.price['value']} #{item.price['currency']} - #{item.uri}"
  end.sort
end

def fetch_page_for_search(seller_name, page)
  shop_page = fetch_shop_items(seller_name, page)
  return [] if shop_page.nil? || shop_page.listings.nil?

  shop_page.listings.map do |item|
    {
      artist: item.release['artist'],
      title: item.release['title'],
      format: item.release['format'] || 'Unknown',
      price: "#{item.price['value']} #{item.price['currency']}",
      uri: item.uri,
      page: page
    }
  end
end

def search_artist(seller_name, query)
  puts
  puts "Searching for '#{query}' across all pages..."

  # First fetch to get total pages if not known
  if @total_pages.nil?
    fetch_shop_items(seller_name, 1)
  end

  return if @total_pages.nil?

  puts "Fetching #{@total_pages} pages in parallel (batches of 5)..."
  puts

  all_listings = []
  mutex = Mutex.new
  batch_size = 5

  (1..@total_pages).each_slice(batch_size) do |page_batch|
    threads = page_batch.map do |page|
      Thread.new do
        listings = fetch_page_for_search(seller_name, page)
        mutex.synchronize { all_listings.concat(listings) }
      end
    end
    threads.each(&:join)
    print "\rFetched #{[page_batch.last, @total_pages].min} of #{@total_pages} pages..."
  end

  matches = all_listings.select { |item| item[:artist].downcase.include?(query.downcase) }

  puts
  puts

  if matches.empty?
    puts "No results found for '#{query}'."
  else
    puts "Found #{matches.size} release(s) matching '#{query}':"
    puts
    matches.group_by { |m| m[:artist] }.each do |artist, releases|
      puts "#{artist} (#{releases.size} releases):"
      releases.each do |r|
        puts "  #{r[:title]} [#{r[:format]}] - #{r[:price]} - #{r[:uri]}"
      end
      puts
    end
  end

  puts "Press (Return) to continue browsing"
  print '>>> '
  gets
end

def fetch_page(seller_name, current_page, opt = 'next')
  page_number = opt == 'previous' ? current_page - 1 : current_page + 1
  puts
  if @page_cache[page_number]
    puts "Loading #{opt} page from cache."
  else
    puts "Fetching #{opt} page. Please wait."
  end
  puts
  run_crawler(seller_name, page_number)
end

def run_crawler(seller_name, current_page_number, previous_page = nil)
  shop_page = previous_page || fetch_shop_items(seller_name, current_page_number)
  artists = group_shop_items_by_artist(shop_page)

  if artists.nil?
    puts "That's the end of #{seller_name}'s inventory!"
    stop_crawler
  end

  page_info = @total_pages ? "Page #{current_page_number} of #{@total_pages} (#{@total_items} total items)" : "Page #{current_page_number}"
  puts "#{seller_name} has #{artists.length} Artist(s) on this page - #{page_info}:"
  puts

  artists.each.with_index { |item, i| puts "#{i + 1}: #{item[:artist]} - #{item[:releases]} releases" }
  puts

  puts "You are on #{page_info}"
  puts 'Input (a) to go to previous page' unless current_page_number == 1
  puts 'Input (z) to go to next page' unless current_page_number == @total_pages
  puts "Input (number) to view an Artist's releases"
  puts 'Input (s) to search for an artist'
  puts 'Input any other key to exit'
  print '>>> '
  option = gets.chomp

  if option == 'a' && current_page_number != 1
    fetch_page(seller_name, current_page_number, 'previous')
  elsif option == 'z' && current_page_number != @total_pages
    fetch_page(seller_name, current_page_number)
  elsif option == 's'
    puts
    puts 'Enter artist name to search:'
    print '>>> '
    query = gets.chomp
    search_artist(seller_name, query)
    run_crawler(seller_name, current_page_number, shop_page)
  elsif option.to_i > 0
    selected_artist = artists[option.to_i - 1][:artist]
    releases = get_artist_releases(shop_page, selected_artist)
    puts
    puts "Viewing #{releases.size} release(s) by '#{selected_artist}' (Title [Format] - Price - Link):"
    puts
    releases.each { |release| puts release }

    puts
    puts "Input (a) to go back to Page #{current_page_number}"
    puts 'Input (z) to go to next Page' unless current_page_number == @total_pages
    puts 'Input any other key to exit'
    print '>>> '
    navigation = gets.chomp

    if navigation == 'a'
      puts
      run_crawler(seller_name, current_page_number, shop_page)
    elsif navigation == 'z' && current_page_number != @total_pages
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

puts 'Discogs Crawler V2 initialized!'
puts

puts 'Please input Seller name:'
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
