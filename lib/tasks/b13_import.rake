require 'kiba'
require_relative 'b13_transformations'
require_relative 'b13_output'
require 'time'
require 'active_support'
require_relative 'progress_bar'
require 'rake'
require 'csv'

namespace :b13 do
  desc 'Drops the audit, element types, elements and provider tables'
  task :etl_drop => :environment do | t, argv |
    AuditEvent.delete_all
    Element.delete_all
    Provider.delete_all
    ElementType.delete_all
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
         rejections_filename: './out/rejections_b13_' + Time.now.strftime("%m-%d-%Y.%H.%M.%S") + '.csv'
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
        end_date:       'End Date'
      }

    when 'mosaic_historic'
      argv.with_defaults(
         filename: '25 May Mosaic Brokerage - Duty.xlsx',
         sheet: 'AuthorisationCompleted-22-05-22',
         header_search: 'Type of Referral',
         rejections_filename: './out/rejections_mosaic_' + Time.now.strftime("%m-%d-%Y.%H.%M.%S") + '.csv'
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
        end_date:       "End Date \n(6 WEEKS Hosp/Enter Manually)"
      }
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
        transform TransformRejectIfMosaicNotInt, mosaic_col: argv[:header_search], rejections: @rejections
        transform TransformCleanUnits
        transform TransformProviderCedar,
               spreadsheet: spreadsheet,
               sheet: sheet,
               header_search: argv[:header_search],
               cedar_col: column_mappings[:cedar],
               provider_col: column_mappings[:provider]
        transform TransformElementCostType
        transform TransformRejectParseCostCentre, rejections: rejections
        destination OutputActiveRecords, progress_bar: @progress_bar, column_mappings: column_mappings
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
