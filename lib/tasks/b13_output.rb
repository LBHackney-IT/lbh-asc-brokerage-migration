# Loads the components into a DB
class   OutputActiveRecords
  def initialize(progress_bar:, column_mappings:)
    @progress_bar = progress_bar
    @column_mappings = column_mappings
  end

  def write(row)
    if !@headers_written
      @headers_written = true
    else
      # find cedar. if its in an array, its been found from a cache
      cedar_number = row[@column_mappings[:cedar]]
      if cedar_number.is_a? Array
        if(cedar_number.length > 1)
          # if more than one cedar number add audit entry
          AuditEvent.create(
            social_care_id: row[@column_mappings[:mosaic_id]],
            message: 'Provider matches multiple CEDAR ids - chose the first available from ' + cedar_number.join(','),
            event_type: 'import_note',
            metadata: '',
            user_id: 0
          )
        end
        cedar_number = cedar_number[0].to_i
      end

      # Get the provider, if there is one provided
      provider = Provider.find_by cedar_number: cedar_number.to_i
      if !provider
        provider = Provider.create(
          name: row[@column_mappings[:provider]],
          type: :spot,
          address: '(unknown)',
          cedar_number: cedar_number.to_i
        )
      end

      service_group = Service.find_by name: row[@column_mappings[:service_group]]
      if !service_group
        service_group = Service.new
        service_group.name = row[@column_mappings[:service_group]]
        service_group.id = Service.maximum(:id).to_i.next
        service_group.position = 1
        service_group.save!
      end

      element_type = ElementType.find_by name: row[@column_mappings[:service_type]]
      if !element_type
        element_type = ElementType.new
        element_type.name = row[@column_mappings[:service_type]]
        element_type.id = ElementType.maximum(:id).to_i.next
        element_type.service_id = service_group.id
        element_type.cost_type = row[@column_mappings[:cycle]]
        element_type.position = 1
        element_type.save!
      end

      element = Element.new
      element.element_type = element_type

      element.social_care_id = row[@column_mappings[:mosaic_id]].to_i

      element.provider = provider
      # element.non_personal_budget = ??

      element.cost 			= row[@column_mappings[:amount]] if row.key? @column_mappings[:amount]
      element.quantity 	= row[@column_mappings[:quantity]] if row.key? @column_mappings[:quantity]

      element.start_date  = row[@column_mappings[:start_date]]
      element.end_date 		= row[@column_mappings[:end_date]]

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