require 'kiba'
require_relative 'b13_transformations'
require_relative 'b13_output'
require 'time'
require 'active_support'
require_relative 'progress_bar'
require 'rake'
require 'csv'
require 'yaml'
require 'fuzzy_match'
require 'amatch'
require_relative './refine'
require_relative './load_providers'

namespace :b13 do
  desc 'Drops the audit, element types, elements and provider tables'
  task :etl_drop => :environment do | t, argv |
    AuditEvent.delete_all
    Element.delete_all
    Provider.delete_all
    ElementType.delete_all
  end

  desc 'Import the cleaned element names and produce a YAML file'
  task :import_cleaned_element_names => :environment do | t, argv |
    argv.with_defaults(
      filename: 'Data for Unboxed 2022.02.01 Status - Work in Progress.xlsx',
      sheet: 'Element review',
      header_search: ' Old element names',
      old_element_names_column: ' Old element names',
      new_element_names_column: 'Reviewed List (New element names)'
    );
    spreadsheet = Roo::Excelx.new argv[:filename]
    sheet = spreadsheet.sheet argv[:sheet]
    replacements = Hash.new
    headers = []
    old_element_index = false
    new_element_index = false

    (1..sheet.last_row).each do | rowNum |
      row = sheet.row(rowNum)
      if !old_element_index && !new_element_index
        # search for header phrase
        if row.include? argv[:header_search]
          old_element_index = row.index argv[:old_element_names_column]
          new_element_index = row.index argv[:new_element_names_column]
        end
      else
        # map the headers array into a hash of the row results
        if !(row[old_element_index].nil? || row[old_element_index].empty?) &&
           !(row[new_element_index].nil? || row[new_element_index].empty?)
          replacements[row[old_element_index].strip] = row[new_element_index].strip
        end
      end
    end
    File.write('element_replacements.yml', replacements.to_yaml)
  end

  desc 'Import provider data'
  task :etl_provider => :environment do | t, argv |
    argv.with_defaults(
      provider_info: {
        file: 'Suppliers Info HA (33)',
        tab: 'Page1_1',
        supplier: 'supplier name',
        cedar: 'supplier reference',
        site: 'address number',
        address: ['address line 1',	'address line 2', 'address line 3', 'address line 4',	'address line 5',	'address line 6',	'postcode']
      },
      sheets_and_tabs: {
        # note: "Finance Client Data 21-22"
        #       only contained PO (purchase orders?) that did not
        #       match any known CEDAR IDs when doing a cursory search
        'B13_26_09_20': {
          '27_09_2020_21_06': {
            supplier: 'Provider',
            cedar: 'CEDAR number (Supplier Id)'
          }
        },
        'Residential Payment Tracker 22-23': {
          'Residential Tracker 22-23': {
            supplier: 'Supplier',
            cedar: 'Cedar ID'
          },
          'Pivot Table 2': {
            supplier: 1,
            cedar: 0,
            follow_previous: true
          },
          'March 22 GL': {
            supplier: 'Supplier Name',
            cedar: 'Supplier'
          }
        },
        'Supported Living Payment Tracker 22-23': {
          'SLS Tracker': {
            supplier: 'Supplier',
            cedar: 'Cedar ID'
          }
        },
        'Nursing Payment Tracker 22-23': {
          'Nursing Tracker': {
            supplier: 'Supplier',
            cedar: 'Cedar ID'
          },
          'March 22 GL': {
            supplier: 'Supplier Name',
            cedar: 'Supplier'
          }
        }
      }
    )

    provider_matches = {
      exact: Hash.new,
      guess: Hash.new
    }

    provider_list, provider_detail, address_list = LoadProviders::load(argv['provider_info']);

    provider_by_name = {}
    provider_by_cedar = {}
    argv['sheets_and_tabs'].each do | spreadsheet_filename, tabs |
      p 'Loading spreadsheet ' + spreadsheet_filename.to_s
      spreadsheet = Roo::Excelx.new spreadsheet_filename.to_s + '.xlsx'
      tabs.each do | tab_name, columns |
        p 'Loading tab ' + tab_name.to_s
        sheet = spreadsheet.sheet tab_name.to_s

        if(columns[:supplier].is_a? Integer)
          supplier_index = columns[:supplier]
          cedar_index = columns[:cedar]
          header_row_number = 0
        else
          header_row_number, headers = FindHeaders.find(sheet: sheet, header_search: columns[:supplier])
          supplier_index = headers.index columns[:supplier]
          cedar_index = headers.index columns[:cedar]
        end
        previous_cedar = nil

        if(sheet.last_row)
          ((header_row_number+1)..sheet.last_row).each do | rowNum |
            row = sheet.row(rowNum)

            if(!columns[:follow_previous_cedar].nil? && columns[:follow_previous_cedar])
              if(row[cedar_index].nil? || row[cedar_index].empty?)
                row[cedar_index] = previous_cedar
              end
            end

            if (!(row[supplier_index].nil? || row[supplier_index].empty?)  &&
               (!(row[cedar_index].nil?) && (row[cedar_index].is_a? Numeric)))
              if(provider_by_name[row[supplier_index]].nil?)
                provider_by_name[row[supplier_index]] = []
              end
              provider_by_name[row[supplier_index]].append(
                {
                  cedar: row[cedar_index].to_i,
                  sheet: spreadsheet_filename,
                  tab: tab_name
                }
              )

              if(provider_by_cedar[row[cedar_index]].nil?)
                provider_by_cedar[row[cedar_index]] = []
              end
              provider_by_cedar[row[cedar_index]].append(
                {
                  supplier: row[supplier_index],
                  sheet: spreadsheet_filename,
                  tab: tab_name
                }
              )
            end
          end
        else
          p 'Could not load sheet ' + tab_name.to_s
        end
      end
    end

    # now convert these into a CSV
    by_cedar_csv = CSV.open('./out/provider_by_cedar_' + Time.now.strftime("%d-%m-%Y.%H.%M.%S") + '.csv', 'w')
    list_sheets_row = ['Sheets and Tabs ➡️', '', '']
    list_tabs_row = ['CEDAR', '# matches', 'supplier list match']
    cell_positions = [];

    argv['sheets_and_tabs'].each do | filename, tabs |
      list_sheets_row.append filename
      tabs.keys.each_with_index do | tab, i |
        # add an empty cell on the sheets row if there is more than one tab
        if i > 0
          list_sheets_row.append ''
        end
        cell_positions[list_tabs_row.size] = filename.to_s + '/' + tab.to_s
        list_tabs_row.append tab.to_s
      end
    end
    by_cedar_csv << list_sheets_row
    by_cedar_csv << list_tabs_row

    # count different values in the row
    def different_value_count(row)
      row = row.drop(3).uniq
      row.size - row.count(nil)
    end

    # provider by cedar first
    provider_by_cedar.each do | cedar_code, matches |
      row = []
      row[0] = cedar_code
      matches.each do | match |
        row[cell_positions.index(match[:sheet].to_s + '/' + match[:tab].to_s)] = match[:supplier].to_s
      end

      # count empty cells
      row[1] = different_value_count row

      # look up cedar matches
      row[2] = provider_list.fetch(format('%06d',cedar_code.to_i), '0')
      by_cedar_csv << row
    end
    by_cedar_csv.close

    by_name_csv = CSV.open('./out/provider_by_name_' + Time.now.strftime("%d-%m-%Y.%H.%M.%S") + '.csv', 'w')
    by_name_csv << list_sheets_row
    list_tabs_row[0] = 'Provider Name'
    by_name_csv << list_tabs_row

    # general provider output
    provider_output_csv = CSV.open('./out/general_provider_match_' + Time.now.strftime("%d-%m-%Y.%H.%M.%S") + '.csv', 'w')
    provider_output_csv << %w(name address type is_archived created_at updated_at cedar_number cedar_site)
    provider_not_found_csv = CSV.open('./out/general_provider_not_found_' + Time.now.strftime("%d-%m-%Y.%H.%M.%S") + '.csv', 'w')
    provider_not_found_csv << list_sheets_row.insert(1, '', '')
    provider_not_found_csv << list_tabs_row.insert(1, 'Probable match', 'Prediction score', 'Probable CEDAR')

    # initialize fuzzy matcher
    fuzzy_locations = FuzzyMatch.new(provider_list.values)
    FuzzyMatch.engine = :amatch

    # now process provider by provider name
    provider_by_name.each do | provider_name, matches |
      row = []
      row[0] = provider_name
      matches.each do | match |
        row[cell_positions.index(match[:sheet].to_s + '/' + match[:tab].to_s)] = match[:cedar].to_s
      end

      # count empty cells
      row[1] = different_value_count row

      # look up cedar matches
      row[2] = provider_list.key(provider_name.downcase)

      by_name_csv << row

      found_provider = false
      # filter what should appear in general output
      #  - has entry in B13 and elsewhere and matches supplier info
      #  - [2] has supplier info
      #  - [3] contains a possible B13
      #  - [4..last] contain other matches
      if(!row[2].nil? && row[2].to_i > 0) # we have cedar
        six_digit_cedar = row[2].nil? ? -1 : format('%06d', row[2].to_i)
        if(!row[2].nil?) # we have supplier info - write it
          found_provider = provider_detail[six_digit_cedar]
        else # look for supplier info in [4..last]
          if(row.size >= 4)
            [4..row.size].each do | index |
              six_digit_for_this_index = format('%06d', row[index].to_i)
              if provider_detail.key? six_digit_for_this_index
                found_provider = provider_detail[six_digit_for_this_index]
              end
            end
          end
        end
      end
      if(!found_provider)
        if(row[3].to_i > 0)
          # look for fuzzy
          p 'Attempt to find fuzzy for row ' + row[0]

          fuzz = fuzzy_locations.find_with_score(row[0].downcase)
          cedar_fuzz = provider_list.key(fuzz[0])
          p 'Found ' + fuzz[0] + ', cedar ' + cedar_fuzz
          row.insert(1, fuzz[0], fuzz[1], cedar_fuzz)
          provider_not_found_csv << row
          provider_matches[:guess][provider_name] = {
            name: row[0],
            suggestion: row[1],
            score: row[2],
            cedar_number: row[3]
          }
        end
      else
        # loop through addresses
        address_list[found_provider[:cedar_number]].each  do | address |
          csv_row = found_provider.values

          csv_row.insert(1, address[:address])
          csv_row.append(address[:site])

          provider_output_csv << csv_row
        end

        provider_matches[:exact][provider_name] = {
          cedar_number: found_provider[:cedar_number],
          name: found_provider[:name],
          sites: address_list[found_provider[:cedar_number]]
        }
      end
    end

    File.write(
      './out/provider_mapping.json',
      JSON.pretty_generate(provider_matches)
    )
    by_name_csv.close
    provider_output_csv.close
    provider_not_found_csv.close
  end

  desc 'Process Provider clarifications from Hackney'
  task :etl_process_provider_clarifications => :environment do | t, argv |
    argv.with_defaults(
      filename: 'Hackney clarifications',
      probable_match_col: 'Probable match from Supplier list ',
      original_provider_string_col: 'Provider Name ',
      is_it_correct: 'Is the probable match correct?',
      added_cedar_number: 'If no, please add (CEDAR number)',
      added_site_id: 'If no, please add (Site ID)'
    )
    spreadsheet = Roo::Excelx.new argv[:filename].to_s + '.xlsx'
    sheet = spreadsheet.sheet(0)
    header_row_number, headers = FindHeaders.find(sheet: sheet, header_search: argv['original_provider_string_col'])

    original_provider_string_col_index = headers.index argv['original_provider_string_col']
    is_it_correct_index = headers.index argv['is_it_correct']
    added_cedar_number_index = headers.index argv['added_cedar_number']
    added_site_id_index = headers.index argv['added_site_id']
    probable_match_col_index = headers.index argv['probable_match_col']
    clarifications = Hash.new

    ((header_row_number + 1)..sheet.last_row).each do | rowNum |
      row = sheet.row(rowNum)
      clarification_info = {}

      def find_site_number(site_name, default = 0)
        site_number = site_name.match /[\[\(](cedar)* Site (\d)?[\]\)]/i
        if !site_number.nil? && Integer(site_number[2], exception: false)
          return site_number[2].to_i
        end
        return default
      end

      # they've found it
      if !row[is_it_correct_index].nil? && (row[is_it_correct_index].to_s.match? /yes/i)
        # it's got a site number
        if row[is_it_correct_index].match? /site number/i
          clarification_info = {
            supplier_string_match: row[probable_match_col_index],
            site: find_site_number(row[original_provider_string_col_index], 0)
          }
        else
          clarification_info = {
            cedar_number: row[added_cedar_number_index],
            site: row[added_site_id_index]
          }
        end
      else
        if !row[is_it_correct_index].nil? && (row[is_it_correct_index].to_s.match? /no/i)
          site_id = row[added_site_id_index].to_i

          if(site_id == 0)
            site_id = find_site_number(
              row[original_provider_string_col_index],
              site_id)
          end

          clarification_info = {
            cedar_number: row[added_cedar_number_index],
            site: site_id
          }
        end
      end
      clarifications[row[original_provider_string_col_index]] = clarification_info
    end
    File.write(
      './out/provider_clarifications_' + Time.now.strftime("%d-%m-%Y.%H.%M.%S") + '.json',
      JSON.pretty_generate(clarifications)
    )

  end

  desc 'Clean provider data - requires open refine to be running on :3333'
  task :etl_find_provider_clusters => :environment do | t, argv |

    # find latest provider by name file
    provider_by_name_file = Dir['./out/provider_by_name*.csv'].last
    timestamp = Time.now.strftime("%d-%m-%Y.%H.%M.%S")
    # create new open refine project
    refine_project = Refine.new({
        "project_name" => 'provider_clean_up_' + timestamp,
        "file_name" => provider_by_name_file,
        'options' => {
          "encoding": "UTF-8",
          "separator":",",
          "ignoreLines":1,
          "headerLines":1,
          "skipDataLines":0,
          "limit":-1,
          "storeBlankRows": false,
          "guessCellValueTypes":false,
          "processQuotes": true,
          "quoteCharacter": "\"",
          "storeBlankCellsAsNulls": true,
          "includeFileSources": false,
          "includeArchiveFileName": false,
          "trimStrings": true
        }.to_json
    })

    clustering_instructions = File.open(File.join(Rails.root, "lib", "tasks", "operations.json")).read
    File.write(
      provider_by_name_file + '.clusters.json',
      JSON.pretty_generate(
        refine_project.call('compute-clusters', JSON.parse(clustering_instructions))
      )
    )
  end

  desc 'Imports all providers from general_provider_match and general_provider_not_found into the database'
  task :etl_import_providers_into_db => :environment do | t, argv |
    Rake::Task["b13:etl_drop"].invoke

    argv.with_defaults(
      provider_info: {
        file: 'Suppliers Info HA (33)',
        tab: 'Page1_1',
        supplier: 'supplier name',
        cedar: 'supplier reference',
        site: 'address number',
        address: ['address line 1',	'address line 2', 'address line 3', 'address line 4',	'address line 5',	'address line 6',	'postcode']
      }
    )
    # latest provider general list
    # provider_match_file = Dir['./out/general_provider_match_*.csv'].last
    provider_clarifications = JSON.parse(File.read(Dir['./out/provider_clarifications_*.json'].last))
    provider_mapping = JSON.parse(File.read('./out/provider_mapping.json'))
    provider_list, provider_detail, address_list = LoadProviders::load(argv['provider_info'])

    provider_mapping['exact'].each do | provider_name, detail |
      # put it in there
      detail['sites'].each do | site |
        cedar_number = format('%06d', detail['cedar_number'].to_i)
        provider = Provider.find_by(
          cedar_number: cedar_number,
          cedar_site: site['site'].to_i
        )
        if !provider
          type = provider_detail[cedar_number].fetch(:type, :spot);
          Provider.create(
            name: provider_name,
            type: type,
            address: site['address'],
            cedar_number: detail['cedar_number'].to_i,
            cedar_site: site['site'].to_i
          )
        end
      end
    end

    provider_clarifications.each do | dirty_provider_name, clarification_detail |
      cedar_number = clarification_detail['cedar_number']
      if(cedar_number)
        cedar_number = format('%06d', clarification_detail['cedar_number'].to_i)
        site_number = clarification_detail.fetch 'site', 0

        provider = Provider.find_by(
          cedar_number: cedar_number,
          cedar_site: site_number
        )
        if !provider
          if provider_detail[cedar_number]
            type = clarification_detail.fetch(:type, :spot);
            address_info = address_list[cedar_number.to_i].find { |a| a[:site] == site_number }
            Provider.create(
              name: provider_detail[cedar_number][:name],
              type: type,
              address: address_info.nil? ? '(unknown)' : address_info[:address],
              cedar_number: cedar_number,
              cedar_site: site_number
            )
          else
            # log that there was no detail for it
          end
        end
      end
    end
  end

  desc 'Imports all three spreadsheet types, one after another, with values being assumed to be newer'
  task :etl_all => :environment do | t, argv |
    ['b13_historic', 'mosaic_historic'].each do |source_type|
      Rake::Task["b13:etl"].invoke source_type
      Rake::Task['b13:etl'].reenable
    end
  end

  desc 'Imports a spreadsheet file'
  task :etl, [:source_type] => :environment do | t, argv |
    source_type = argv['source_type'] || nil

    case source_type
    when 'b13_historic'
      # set some defaults
      argv.with_defaults(
         filename: 'B13_26_09_20.xlsx',
         sheet: '27_09_2020_21_06',
         header_search: 'Mosaic ID',
         cedar_col: 'CEDAR number (Supplier Id)',
         provider_col: 'Provider',
         rejections_filename: './out/rejections_b13_' + Time.now.strftime("%d-%m-%Y.%H.%M.%S") + '.csv'
      )

      # declare columns
      column_mappings = {
        provider:       'Provider',
        cedar:          'CEDAR number (Supplier Id)',
        service_group:  'Service Group',
        service_type:   'Service Type',
        cycle:          'Cycle',
        mosaic_id:      'Mosaic ID',
        amount:         'Amount',
        quantity:       'Qty',
        start_date:     'Start Date',
        end_date:       'End Date',
        element_name:   'Element',
        service_user_name: 'Service User',
        service_user_name_format: 'l,f'
      }

      default_values = {
        details:        'B13 Imported'
      }

    when 'mosaic_historic'
      argv.with_defaults(
         filename: '25 May Mosaic Brokerage - Duty.xlsx',
         sheet: 'AuthorisationCompleted-22-05-22',
         header_search: 'Type of Referral',
         rejections_filename: './out/rejections_mosaic_' + Time.now.strftime("%d-%m-%Y.%H.%M.%S") + '.csv'
      )

      # declare columns
      column_mappings = {
        provider:       'Care Provider',
        cedar:          'CEDAR number (Supplier Id)', # this doesn't exist, needs to pass down from first spreadsheet
        service_group:  'Type of POC',
        service_type:   'Service Type', # these needs to be mapped to that element spreadsheet
        cycle:          'Cycle',
        mosaic_id:      'Mosaic No',
        amount:         "Amount \nFULL WEEK/TODATE\nWeeks Owed £\n",
        quantity:       'Qty', # ??
        start_date:     'Start Date',
        end_date:       "End Date \n(6 WEEKS Hosp/Enter Manually)",
        details:        "Care Package Description",
        service_user_name: 'Name',
        service_user_name_format: 'f l',
        service_user_dob: 'DOB.',
        service_user_dob_format: '%d/%m/%Y'
      }

      default_values = {}
    else
      abort 'Wrong source type given. Supported: b13_historic, mosaic_historic'
    end

    p 'Importing...'

    rejections = OutputCSV.new(filename: argv['rejections_filename'], progress_bar: @progress_bar)
    rejections.write(['Rejections for ' + source_type])

    provider_clarifications = JSON.parse(File.read(Dir['./out/provider_clarifications_*.json'].last))
    provider_mappings = JSON.parse(File.read('./out/provider_mapping.json'))

    Kiba.run(
      Kiba.parse do
        @progress_bar = ProgressBar.new(total: 1, description: 'Rows imported')
        spreadsheet = Roo::Excelx.new argv[:filename]
        sheet = argv[:sheet]
        source B13SourceSpreadsheet,
               spreadsheet: spreadsheet,
               sheet: sheet,
               header_search: argv[:header_search],
               progress_bar: @progress_bar,
               rejections: rejections
        transform TransformCleanNBSP
        transform TransformRemoveHTML
        transform TransformRejectIfMosaicNotInt, mosaic_col: argv[:header_search], rejections: @rejections
        transform TransformCleanUnits

        transform TransformCostToPositive, cost_col: column_mappings[:amount]
        transform TransformElementFNCC
        transform TransformProviderCedar,
                  spreadsheet: spreadsheet,
                  sheet: sheet,
                  header_search: argv[:header_search],
                  cedar_col: column_mappings[:cedar],
                  provider_col: column_mappings[:provider]
        transform TransformElementCostType
        transform TransformRejectParseCostCentre, rejections: rejections

        transform TransformServiceUsername, service_user_name_col: column_mappings[:service_user_name], format: column_mappings[:service_user_name_format]

        transform TransformDOB, dob_col: column_mappings[:service_user_dob], format: column_mappings[:service_user_dob_format]

        transform TransformAddDefaults,
                  default_values: default_values

        destination OutputActiveRecords,
                    progress_bar: @progress_bar,
                    column_mappings: column_mappings,
                    replacements: YAML.load_file('element_replacements.yml'),
                    provider_clarifications: provider_clarifications,
                    provider_mappings: provider_mappings
      end
    )
    rejections.close
    p "...Finished!"
  end

  desc 'Exports the elements from the database into a CSV'
  task :etl_export_csv => :environment do | t, argv |
    export_file = OutputCSV.new(filename: './out/exported_elements_' + Time.now.strftime("%m-%d-%Y.%H.%M.%S") + '.csv');

    headers_done = false
    results = ActiveRecord::Base.connection.execute("SELECT * FROM elements LEFT JOIN providers ON elements.provider_id = providers.id")
    results.each do | row |
      if !headers_done
        export_file.write row.keys
        headers_done = true
      end
      export_file.write row
    end
  end
end
