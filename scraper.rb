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
  items = data["helpAtHomeFinderResponse"]["helpAtHomeFinderOutput"]["helpAtHomeServices"]["helpAtHomeService"]
  items.map{|i| extract_leaf_nodes(i)}
end

records = get_suburbs_chunk[:records]
p records

# p get_service_types

# p find_services("Personal Care", "KATOOMBA", "NSW", "2780")
