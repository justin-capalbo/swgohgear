require 'httparty'
require 'nokogiri'
require 'json'
require 'pry'
require 'csv'

characters = ["commander-luke-skywalker"]

characters.each do |character|
  #This is how we request the page we're going to scrape
  page = HTTParty.get("https://swgoh.gg/characters/#{character}/gear/")
  parse_page = Nokogiri::HTML(page)

  # Empty data structures to hold our gear
  gear_summary = [{}]
  total_gear = Hash.new()

  #Primary container
  container = parse_page.xpath("//div[@class = 'content-container-primary']").first 

  #List items
  current_level = 0
  container.xpath(".//li").each do |li|
    
    #Determine if we've come to a new gear level
    li.xpath('.//h4').each do |h4|
      lvltext = h4.text
      gear_text = lvltext[lvltext.index('Level')..lvltext.index('Level') + 9]
      current_level = gear_text[/\d+/].to_i
    end

    #Instead we have gear
    base_item = ""
    li.xpath('.//div[contains(@class,"media-heading")]//h5').each do |h5|
      base_item = h5.text
      gear_summary << { level: current_level, gear: h5.text } unless h5.text.start_with?('Unknown') 
    end

    #Check for subcomponents
    subcomponents = Hash.new(0)
    li.xpath(".//a[contains(@class,'gear-tooltip')]").each do |item|
      #Any sub components
      item.css('.list-inline li').map do |sub_item|
        #Qty
        comp_qty = sub_item.text[/\d+/].to_i

        #Name
        sub_comp = sub_item.css('.gear-icon-micro')
        compname = sub_comp.attribute("title").text

        #Add
        subcomponents[compname] += comp_qty

        total_gear[compname] = Hash.new(0) if total_gear[compname].nil?
        total_gear[compname][current_level] += comp_qty
      end
    end

    # Add base item to gear if it had no components
    if subcomponents.empty?
      if base_item.downcase.start_with?('mk')
        total_gear[base_item] = Hash.new(0) if total_gear[base_item].nil?
        total_gear[base_item][current_level] += 1
      end
    else
      gear_summary.last[:components] = subcomponents if subcomponents.any?
    end
  end

  #Output result to file
  CSV.open("#{character}.csv", "wb") do |csv|
    #Labels
    nums = []
    12.times { |num| nums << "Gear Level #{num + 1}" }
    csv << ["Item Name","Total"].push(*nums)

    #Items
    total_gear.keys.sort_by { |k| k.downcase[/\d+/].to_i }.each do |item|
       row = Array.new(14, "")
       row[0] = item
       row[1] = total_gear[item].inject(0) { |total, (lvl, qty)| total + qty }
       total_gear[item].each do |lvl, qty|
         row[lvl + 1] = "#{qty}"
       end
       csv << row
    end
  end
end

Pry.start(binding)
