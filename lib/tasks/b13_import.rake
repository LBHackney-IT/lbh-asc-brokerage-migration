require 'kiba'
require_relative 'b13_transformations'
require_relative 'b13_output'
require 'time'
require 'active_support'
require_relative 'progress_bar'
require 'rake'
require 'csv'
require 'yaml'
require_relative './refine'

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
        cedar: 'supplier reference'
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

    # load provider list
    provider_list = {}
    spreadsheet = Roo::Excelx.new argv['provider_info'][:file].to_s + '.xlsx'
    sheet = spreadsheet.sheet argv['provider_info'][:tab].to_s
    header_row_number, headers = FindHeaders.find(sheet: sheet, header_search: argv['provider_info'][:supplier])
    supplier_index = headers.index argv['provider_info'][:supplier]
    cedar_index = headers.index argv['provider_info'][:cedar]
    ((header_row_number+1)..sheet.last_row).each do | rowNum |
      row = sheet.row(rowNum)
      provider_list[row[cedar_index].to_s.strip] = row[supplier_index].to_s.strip.downcase
    end

    provider_by_name = {}
    provider_by_cedar = {}
    p argv['sheets_and_tabs']
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
    end
    by_name_csv.close
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
      refine_project.call('compute-clusters', JSON.parse(clustering_instructions)).to_json
    )

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
        element_name:   'Element'
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
        details:        "Care Package Description"
      }

      default_values = {}
    else
      abort 'Wrong source type given. Supported: b13_historic, mosaic_historic'
    end

    p 'Importing...'

    rejections = OutputCSV.new(filename: argv['rejections_filename'], progress_bar: @progress_bar)
    rejections.write(['Rejections for ' + source_type])

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
        transform TransformRejectIfMosaicNotInt, mosaic_col: argv[:header_search], rejections: @rejections
        transform TransformCleanUnits
        transform TransformElementFNCC
        transform TransformProviderCedar,
                  spreadsheet: spreadsheet,
                  sheet: sheet,
                  header_search: argv[:header_search],
                  cedar_col: column_mappings[:cedar],
                  provider_col: column_mappings[:provider]
        transform TransformElementCostType
        transform TransformRejectParseCostCentre, rejections: rejections

        transform TransformAddDefaults,
                  default_values: default_values

        destination OutputActiveRecords,
                    progress_bar: @progress_bar,
                    column_mappings: column_mappings,
                    replacements: YAML.load_file('element_replacements.yml')
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
      p row
      if !headers_done
        export_file.write row.keys
        headers_done = true
      end
      export_file.write row
    end
  end
end
