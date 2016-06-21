require 'scraperwiki'
require 'rest-client'

def get_suburbs_chunk
  # Read in a page
  page = RestClient.get("https://servicefinder.myagedcare.gov.au/api/nhsd/v1/reference/set/general;16072014;suburb/search",
    {"x-api-key" => '7ca4c25771c54ca283c682a185e72277'})

  d = JSON.parse(page)

  next_url = d["response"]["_links"]["next"]["href"]
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

# TODO Get all the places (just getting the first 1000 for the time being)
puts "Getting places..."
places = get_suburbs_chunk[:records]
puts "Getting all the service types..."
service_types = get_service_types

places.each do |place|
  puts "Getting data for #{place[:suburb]}, #{place[:state]}, #{place[:postcode]}..."
  service_types.each do |type|
    puts "#{type}..."
    record = find_services(type, place[:suburb], place[:state], place[:postcode])
    #p record
    # TODO Check that we aren't saving the same data again and again
    ScraperWiki.save_sqlite(["iD"], record)
  end
end
