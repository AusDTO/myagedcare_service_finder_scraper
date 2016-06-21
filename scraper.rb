require 'scraperwiki'
require 'mechanize'
require 'rest-client'

def get_suburbs_chunk(agent)
  # Read in a page
  page = agent.get("https://servicefinder.myagedcare.gov.au/api/nhsd/v1/reference/set/general;16072014;suburb/search",
    [], nil, {"x-api-key" => '7ca4c25771c54ca283c682a185e72277'})

  d = JSON.parse(page.body)

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

# agent = Mechanize.new
#
# records = get_suburbs_chunk(agent)[:records]
# p records

p get_service_types
