require 'scraperwiki'
require 'mechanize'

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

agent = Mechanize.new

p get_suburbs_chunk(agent)
