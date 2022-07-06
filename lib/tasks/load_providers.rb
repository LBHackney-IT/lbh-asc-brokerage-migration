require 'roo'

class LoadProviders
  def self.load(provider_info)

    # load provider list
    provider_list = {}
    provider_detail = {}
    spreadsheet = Roo::Excelx.new provider_info[:file].to_s + '.xlsx'
    sheet = spreadsheet.sheet provider_info[:tab].to_s
    header_row_number, headers = FindHeaders.find(sheet: sheet, header_search: provider_info[:supplier])
    supplier_index = headers.index provider_info[:supplier]
    cedar_index = headers.index provider_info[:cedar]
    site_index = headers.index provider_info[:site]
    
    address_indices = [];
    headers.each_with_index do |col, index|
      if provider_info[:address].include? col
        address_indices.append index
      end
    end
    
    address_list = Hash.new
    
    framework_providers = YAML.load_file('framework_providers.yml')
    ((header_row_number+1)..sheet.last_row).each do | row_num |
      row = sheet.row(row_num)
      cedar_number = row[cedar_index].to_s.strip.to_i
      provider_detail[row[cedar_index].to_s.strip] = {
        name: row[supplier_index],
        type: (framework_providers.include? row[supplier_index]) ? :framework : :spot,
        is_archived: false,
        created_at: DateTime.now,
        updated_at: DateTime.now,
        cedar_number: cedar_number
      }
      # add to address list
      if !address_list.include? cedar_number
        address_list[cedar_number] = []
      end
    
      site_id = row[site_index].to_s.strip.to_i
      address_list[cedar_number].append({
        site: site_id,
        address: row.select.with_index { | value, index | address_indices.include? index }.compact.join("\n"),
      })
      provider_list[row[cedar_index].to_s.strip] = row[supplier_index].to_s.strip.downcase
    end

    return [provider_list, provider_detail, address_list]
  end
end 