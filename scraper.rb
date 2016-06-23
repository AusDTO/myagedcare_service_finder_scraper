require 'scraperwiki'
require 'rest-client'

def get_suburbs_chunk(url)
  # Read in a page
  page = RestClient.get("https://servicefinder.myagedcare.gov.au/api/nhsd/v1" + url,
    {"x-api-key" => '7ca4c25771c54ca283c682a185e72277'})

  d = JSON.parse(page)

  if d["response"]["_links"]["next"]
    next_url = d["response"]["_links"]["next"]["href"]
  end
  records = d["response"]["_embedded"]["referenceItem"].map do |item|
    a = item["itemDescription"].split(";")
    {suburb: a[0], postcode: a[1].strip, state: a[2].strip}
  end
  {next_url: next_url, records: records}
end

def get_service_types
  result = JSON.parse(RestClient.post("https://servicefinder.myagedcare.gov.au/api/acg/v1/retrieveServiceCatalogue",
    '{"retrieveServiceCatalogueRequest":{"retrieveServiceCatalogueInput":""}}',
    content_type: 'application/json', x_api_key: '7ca4c25771c54ca283c682a185e72277'))
  # TODO Check if we need to take account of activeFlag
  result["retrieveServiceCatalogueResponse"]["retrieveServiceCatalogueOutput"]["services"]["service"].map{|t| t["serviceType"]}
end

def extract_leaf_nodes(h)
  # Pick out the leaf nodes and name attributes based on the leaf nodes
  result = {}
  #item.
  h.each do |k, v|
    if v.kind_of?(Hash)
      result.merge!(extract_leaf_nodes(v))
    else
      result[k] = v
    end
  end
  result
end

def find_services(serviceType, suburb, state, postcode)
  request_body = {
    "helpAtHomeFinderRequest" => {
      "helpAtHomeFinderInput" => {
        "serviceType" => serviceType,
        "clientLocationSearch" => {
          "localitySearch" => {
            "suburb" => suburb,
            "state" => state,
            "postcode" => postcode
          }
        }
      }
    }
  }

  data = JSON.parse(RestClient.post("https://servicefinder.myagedcare.gov.au/api/acg/v1/helpAtHomeFinder",
    request_body.to_json,
    content_type: 'application/json', x_api_key: '7ca4c25771c54ca283c682a185e72277'))
  output = data["helpAtHomeFinderResponse"]["helpAtHomeFinderOutput"]
  # Wow. Absolutely no consistency in how the data is returned. If there is no result
  # then why return an empty array? Well, that would just make it TOO easy
  if output["helpAtHomeServices"]
    items = output["helpAtHomeServices"]["helpAtHomeService"]
  else
    items = []
  end
  # Seems that the result of this isn't always an array. Am I doing something wrong here?
  items = [items] unless items.kind_of?(Array)
  items.map{|i| extract_leaf_nodes(i)}
end

def get_places
  url = "/reference/set/general;16072014;suburb/search?offset=1000&limit=1000"

  c = 0
  next_url = true
  places = []
  while next_url
    url = "/reference/set/general;16072014;suburb/search?offset=#{c * 1000}&limit=1000"
    chunk = get_suburbs_chunk(url)
    next_url = chunk[:next_url]
    places += chunk[:records]
    c += 1
  end
  places
end


puts "Getting places..."
places = get_places

puts "Getting all the service types..."
service_types = get_service_types

if ScraperWiki.get_var("suburb")
  suburb = ScraperWiki.get_var("suburb")
  state = ScraperWiki.get_var("state")
  postcode = ScraperWiki.get_var("postcode")
  puts "Restarting scraper from the beginning of #{suburb}, #{state}, #{postcode}"
  i = places.index(suburb: suburb, state: state, postcode: postcode)
  places = places[i..-1]
end

places.each do |place|
  puts "Getting data for #{place[:suburb]}, #{place[:state]}, #{place[:postcode]}..."
  ScraperWiki.save_var("suburb", place[:suburb])
  ScraperWiki.save_var("state", place[:state])
  ScraperWiki.save_var("postcode", place[:postcode])
  service_types.each do |type|
    puts "#{type}..."
    record = find_services(type, place[:suburb], place[:state], place[:postcode])
    #p record
    # TODO Check that we aren't saving the same data again and again
    # A particular organisation (keyed by iD) might provide services in multiple
    # outlets (keyed by outletID) and each outlet provides services to multiple locations.
    ScraperWiki.save_sqlite(["outletID"], record)
  end
end

ScraperWiki.save_var("suburb", nil)
ScraperWiki.save_var("state", nil)
ScraperWiki.save_var("postcode", nil)
