require 'csv'
require 'roo'
require 'bigdecimal'
require 'active_support'
require_relative './find_headers'

### Extract ###
# Loads from B13 spreadsheet
class B13SourceSpreadsheet
	def initialize(yield_header: false, spreadsheet:, sheet:, header_search:, progress_bar:, rejections:)
		@spreadsheet = spreadsheet
		@default_sheet = sheet
		@header_search = header_search
		@yield_header = yield_header
		@progress_bar = progress_bar
		@rejections = rejections
	end

	def each
		sheet = @spreadsheet.sheet(@default_sheet)

		headers = Hash.new

		@progress_bar.set_total(sheet.last_row)

		start_row, headers = FindHeaders.find(sheet: sheet, header_search: @header_search)
		if(@yield_header)
			yield(headers)
		end

		((start_row + 1)..sheet.last_row).each do | rowNum |
			row = sheet.row(rowNum)
			# map the headers array into a hash of the row results
			row_hash = Hash.new
			headers.each_with_index { | header, col |
				if(header)
					row_hash[header] = row[col]
				end
			}
			yield row_hash
		end
	end
end

### Transform ###
# Only adds entries with mosaic ID given
class TransformRejectIfMosaicNotInt
	def initialize(mosaic_col:, rejections:)
		@mosaic_col = mosaic_col
		@rejections = rejections
	end
	def process(row)
		if(!@headers_written)
			@headers_written = true
			return row
		else
			number = row[@mosaic_col]

			# numbers come as float
			if(number.is_a? Float)
				bd = BigDecimal(number.to_s)
				if bd.frac == BigDecimal("0")
					return row
				else
					@rejections.write row.merge({ reason: 'Rejected as mosaic not int'})

					return nil
				end
			end

			return nil
		end
	end
end

class TransformCleanUnits
	def initialize(unit_col = 'Unit')
		@unit_col = unit_col
	end
	def process(row)
		case row[@unit_col].to_s.downcase
		when 'days', 'day', 'nights'
			row[@unit_col] = 'daily'
		when 'unit of measure', 'units'
			row[@unit_col] = 'unit'
		when 'meal'
			row[@unit_col] = 'meal'
		when 'hours'
			row[@unit_col] = 'hour'
		when 'other one off payment'
			row[@unit_col] = 'other_one_off'
		when 'unit', 'units'
			row[@unit_col] = 'unspecified'
		end
		row
	end
end

class TransformElementFNCC
	def initialize

	end
	def process(row)

		row
	end
end

# replaces any weird unicode non breaking spaces with a plain ' '
class TransformCleanNBSP
	def initialize
	end
	def process(row)
		row.map do |key, value|
			if value.is_a? String
				value = value.gsub(/[[:space:]]/, ' ')
			end
			[key, value]
		end
		row.to_h
	end
end

# If there is no CEDAR number provided, search for it elsewhere in sheet
class TransformProviderCedar
	def initialize(spreadsheet:, sheet:, header_search:, cedar_col:, provider_col:)
		@spreadsheet = spreadsheet
		@sheet = sheet.to_s
		@cedar_col = cedar_col
		@provider_col = provider_col
		@header_search = header_search
		@@provider_cache = Hash.new
	end
	def process(row)
		if(!@headers_written)
			@headers_written = true
			return row
		else
			# if there is a Provider string but no cedar code
			if row[@cedar_col].blank? && !row[@provider_col].blank?
				row[@cedar_col] = get_cedar row[@provider_col]
			end
		end
		row
	end
	def get_cedar(provider_name)
		# if no cache, set it up
		if @@provider_cache.empty?
			sheet = @spreadsheet.sheet(@sheet)

			start_row, headers = FindHeaders.find(sheet: sheet, header_search: @header_search)

			# find location of cedars and providers
			provider_index = headers.index @provider_col
			cedar_index = headers.index @cedar_col

			((start_row+1)..sheet.last_row).each do | rowNum |
				row = sheet.row(rowNum)
				# check there is both provider and cedar, and cedar is numeric and over 0
				if !(row[provider_index].nil? || row[provider_index].empty?) &&
					 !(row[cedar_index].nil?) &&
					 row[cedar_index].is_a?(Numeric) &&
					 row[cedar_index] > 0
					if !@@provider_cache.key? row[provider_index]
						@@provider_cache[row[provider_index]] = [row[cedar_index].to_i]
					else
						@@provider_cache[row[provider_index]].append[row[cedar_index].to_i]
					end
				end
			end
		end

		# return cache
		return @@provider_cache[provider_name]
	end
end

class TransformElementCostType
	def initialize(cycle_col = 'Cycle')
		@cycle_col = cycle_col
	end
	def process(row) # has to be: hourly,daily,weekly,transport,one_off")
		case row[@cycle_col].to_s.downcase
		when '4week'
			row[@cycle_col] = 'weekly'
		when 'once'
			row[@cycle_col] = 'one_off'
		when 'vary'
			row[@cycle_col] = 'one_off'
		when 'weekly', 'week'
			row[@cycle_col] = 'weekly'
		end
		row
	end
end

class TransformRejectParseCostCentre
	def initialize(rejections:)
		@rejections = rejections
	end
	def process(row)
		cost_code = row['Budget/Subjective Code']
		if cost_code
			# remove any double dashes at the start
			cost_code = cost_code.sub(/^--/, '')

			# there is no cost centre given
			if(cost_code.start_with? '--')
				cost_code_parts = cost_code.split('-')
				row[:cost_centre] = nil
				row[:cost_subjective] = cost_code_parts[0] || ''
				row[:cost_analysis] = cost_code_parts[1] || ''
			else # default format
				cost_code_parts = cost_code.split('-')
				row[:cost_centre] = cost_code_parts[0] || ''
				row[:cost_subjective] = cost_code_parts[1] || ''
				row[:cost_analysis] = cost_code_parts[2] || ''
				return row
			end
		end
		# we don't want anything without a cost code
		@rejections.write row.merge({reason: 'Rejected parse cost centre'})
		nil
	end
end

class TransformAddDefaults
	def initialize(default_values:)
		@default_values = default_values
	end
	def process(row)
		@default_values.each do | default_name, default_value |
			if !row.has_key? default_name
				row[default_name] = default_value
			end
		end
		row
	end
end

### Load ###
# Loads the components into an output CSV
class OutputCSV
	def initialize(filename:, progress_bar: nil)
		@filename = filename
		@csv = CSV.open(filename, 'w')
		@progress_bar = progress_bar
	end

	def write(row)
		if !@headers_written
			@headers_written = true
			@csv << row
		else
			@csv << row.values
			if(@progress_bar)
				@progress_bar.increment
			end
		end
	end

	def close
		@csv.close
	end
end
