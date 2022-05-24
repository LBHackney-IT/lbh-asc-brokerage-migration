require 'csv'
require 'roo'
require 'bigdecimal'
require 'active_support'

### Extract ###
# Loads from B13 spreadsheet
class B13SourceSpreadsheet
	def initialize(yield_header: false, filename:, sheet:, header_search:, progress_bar:)
		@filename = filename
		@default_sheet = sheet
		@header_search = header_search
		@yield_header = yield_header
		@progress_bar = progress_bar
	end

	def each
		spreadsheet = Roo::Excelx.new @filename
		sheet = spreadsheet.sheet(@default_sheet)

		headers = Hash.new

		@progress_bar.set_total(sheet.last_row)

		(1..sheet.last_row).each do | rowNum |
			row = sheet.row(rowNum)
			if headers.empty?
				# search for header phrase
				if row.include? @header_search
					headers = row
					if(@yield_header)
						yield(headers)
					end
				end
			else
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
end

### Transform ###
# Only adds entries with mosaic ID given
class TransformDropIfMosaicNotInt
	def initialize(mosaic_col:)
		@mosaic_col = mosaic_col
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
		when 'days'
			row[@unit_col] = 'day'
		when 'unit of measure', 'units'
			row[@unit_col] = 'unit'
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

class TransformParseCostCentre
	def initialize
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
		nil
	end
end

### Load ###
# Loads the components into an output CSV
class OutputCSV
	def initialize(filename:)
		@filename = filename
		@csv = CSV.open(filename, 'w')
	end

	def write(row)
		if !@headers_written
			@headers_written = true
			@csv << row
		else
			@csv << row.values
		end
	end

	def close
		@csv.close
	end
end

### Load ###
# Loads the components into a DB
class OutputActiveRecords
	def initialize(progress_bar:)
		@progress_bar = progress_bar
	end

	def write(row)
		if !@headers_written
			@headers_written = true
		else
			# Get the provider, if there is one provided
			provider = (row.key? 'Provider') ? Provider.find_or_create_by(
				name: row['Provider'],
				type: :spot,
				address: 'eg'
			) : nil

			service_group = Service.find_by name: row['Service Group']
			if !service_group
				service_group = Service.new
				service_group.name = row['Service Group']
				service_group.id = Service.maximum(:id).to_i.next
				service_group.position = 1
				service_group.save!
			end

			element_type = ElementType.find_by name: row['Service Type']
			if !element_type
				element_type = ElementType.new
				element_type.name = row['Service Type']
				element_type.id = ElementType.maximum(:id).to_i.next
				element_type.service_id = service_group.id
				element_type.cost_type = row['Cycle']
				element_type.position = 1
				element_type.save!
			end

			element = Element.new
			element.element_type = element_type

			element.social_care_id = row['Mosaic ID']

			element.provider = provider
			# element.non_personal_budget = ??

			# element.payee			= row['Payee'] if row.key? 'Payee'
			element.cost 			= row['Amount'] if row.key? 'Amount'
			element.quantity 	= row['Qty'] if row.key? 'Qty'

			# element.cost_centre = row[:cost_centre]
			# element.cost_subjective = row[:cost_subjective]
			# element.cost_analysis = row[:cost_analysis]

			element.start_date  = row['Start Date']
			element.end_date 		= row['End Date']

			element.non_personal_budget = true

			element.details = 'Details'

			# if row.key? 'Cycle'
			# 	element.cycle = row['Cycle']
			# 	element.unit = row['Unit'].downcase if row.key? 'Unit'
			# end
			element.save!
			@progress_bar.increment
		end
	end

	def close
	end
end