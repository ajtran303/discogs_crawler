# Discogs Crawler

I love shopping for music on the Discogs Marketplace!

I'm writing this crawler so that I can browse seller's inventories more effectively.

On the website, when I visit a seller, I have to visually scan through their whole inventory (250 entries per page) until I find something that might interest me. There is a search option if I know specifically what I'm looking for from a certain seller. But sometimes I don't know what I'm looking for in particular.

Using the website:
```
Go to seller page
Sort store inventory by "Artist A-Z", showing 250 per page
Scroll the entire page until I find something that I'm interested in.
This takes a long time because Artists can have many releases, and each release is displayed as a separate item.
I typically will browse a seller's shop until I discover Artists I recognize and am interested in.
The time it takes to browse increases with the amount of items a seller has in their store.
It's not uncommon for sellers to have thousands of items.
It would be a lot easier to browse if there was an option to view ONLY the Artists.
```

The problem is that it can take a long time to go through an entire seller's store until I find music that I'm interested in. And I don't know what is available from a seller until it shows up while I am browsing their store. Even though there is a search function, sometimes I am not looking for anything in particular. Rather, I'm just interested in what Artists are in that seller's store.

So I have an idea. Let's use the Discogs API to collect data from a seller's store and then group the items together by certain categories. I'm going to start by grouping by the Artists. That way, when I use this Crawler, I can easily visit a seller and know right away which Artists are available in their store. In further iterations, I might want to also filter the results by available formats, such as Vinyl or Cassette.

Reference: [Discogs API Documentation](https://www.discogs.com/developers/)