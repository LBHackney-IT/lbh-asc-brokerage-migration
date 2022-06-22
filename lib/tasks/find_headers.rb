require 'roo'

class FindHeaders
  def self.find(sheet:, header_search:)
    (1..sheet.last_row).each do | rowNum |
      row = sheet.row(rowNum)
      # search for header phrase
      if row.include? header_search
        return [rowNum, row]
      end
    end
    nil
  end
end