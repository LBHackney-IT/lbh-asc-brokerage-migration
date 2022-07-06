# Loads the components into a DB
class OutputActiveRecords
  def initialize(progress_bar:,
                 column_mappings:,
                 replacements:,
                 provider_clarifications:,
                 provider_mappings:)
    @progress_bar = progress_bar
    @column_mappings = column_mappings
    @replacements = replacements
    @provider_clarifications = provider_clarifications
    @provider_mappings = provider_mappings
  end

  def write(row)
    if !@headers_written
      @headers_written = true
    else
      # look up element to see if it exists yet
      # attempts to match by social_care_id and start_date and cost
      element = Element.find_by( {
        social_care_id:   row[@column_mappings[:mosaic_id]],
        start_date:       row[@column_mappings[:start_date]],
        cost:             row[@column_mappings[:amount]]
      })

      # find cedar. if its in an array, its been found from a cache
      cedar_number = row[@column_mappings[:cedar]]
      if cedar_number.is_a? Array
        if(cedar_number.length > 1)
          # if more than one cedar number add audit entry
          AuditEvent.create(
            social_care_id: row[@column_mappings[:mosaic_id]],
            message: 'Provider matches multiple CEDAR ids - chose the first available from ' + cedar_number.join(','),
            event_type: 'import_note',
            metadata: {:cedars => cedar_number},
            user_id: 1
          )
        end
        cedar_number = cedar_number[0].to_i
      end

      # Try getting the provider by CEDAR
      # A lot of incoming sheets have no correct CEDAR, so if none
      # then look up by matching string against provider_mapping['exact']
      # and provider_clarifications[string]
      provider = Provider.find_by(
        cedar_number: format('%06d', cedar_number.to_i),
        cedar_site: 0
      )
      if !provider
        provider_name = row[@column_mappings[:provider]]
        if @provider_mappings['exact'][provider_name]
          # we have a CEDAR from the exact matches
          provider_mapping = @provider_mappings['exact'][provider_name]
          provider = Provider.find_by(
            cedar_number: format('%06d', provider_mapping['cedar_number']),
            cedar_site: provider_mapping['sites'][0]['site']
          )
        else
          cedar_number = format('%06d', @provider_clarifications[provider_name]['cedar_number'].to_i)
          cedar_site = @provider_clarifications[provider_name]['site'].to_i
          provider = Provider.find_by(
            cedar_number: cedar_number,
            cedar_site: cedar_site
          )
        end

        if !provider
          # log that we couldnt get provider info
          AuditEvent.create(
            social_care_id: row[@column_mappings[:mosaic_id]],
            message: 'Could not locate provider from list ',
            event_type: 'import_note',
            metadata: {},
            user_id: 1
          )
        end
      end

      service_group = Service.find_by name: row[@column_mappings[:service_group]]
      if !service_group
        service_group = Service.new
        service_group.name = row[@column_mappings[:service_group]]
        service_group.id = Service.maximum(:id).to_i.next
        service_group.position = 1
        service_group.save!
      end

      # see if the element name needs updating according to replacements
      element_name = row[@column_mappings[:element_name]]
      if @replacements.has_key? element_name
        element_name = @replacements[element_name]
      end

      element_type = ElementType.find_by name: element_name
      if !element_type
        element_type = ElementType.new
        element_type.name = element_name
        element_type.id = ElementType.maximum(:id).to_i.next
        element_type.service_id = service_group.id
        element_type.cost_type = row[@column_mappings[:cycle]]
        element_type.position = 1
        element_type.save!
      end

      if !element
        element= Element.new
      end
      element.element_type = element_type

      element.social_care_id = row[@column_mappings[:mosaic_id]].to_i
      element.cost 			= row[@column_mappings[:amount]] if row.key? @column_mappings[:amount]
      element.quantity 	= row[@column_mappings[:quantity]] if row.key? @column_mappings[:quantity]

      element.start_date  = row[@column_mappings[:start_date]]
      element.end_date 		= row[@column_mappings[:end_date]]

      element.non_personal_budget = true

      element.details = 'Details'

      if(!provider)
        AuditEvent.create(
          social_care_id: row[@column_mappings[:mosaic_id]],
          message: 'No provider when creating element',
          event_type: 'import_note',
          metadata: {},
          user_id: 1
        )
      else
        element.provider = provider
        element.save!
      end

      @progress_bar.increment
    end
  end

  def close
  end
end