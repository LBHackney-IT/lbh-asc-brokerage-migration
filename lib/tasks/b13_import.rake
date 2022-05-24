require 'kiba'
require_relative 'b13_source'
require 'time'
require 'active_support'
require_relative 'progress_bar'

namespace :b13 do
  desc 'Imports a B13 excel file'
  task :etl => :environment do | t, argv |
    # set some defaults
    argv.with_defaults(filename: 'B13_26_09_20.xlsx', sheet: '27_09_2020_21_06', header_search: 'Mosaic ID')
    puts "Importing..."
    Kiba.run(
      Kiba.parse do
        @progress_bar = ProgressBar.new(total: 1, description: 'Rows imported')
        source B13SourceSpreadsheet,
               filename: argv[:filename],
               sheet: argv[:sheet],
               header_search: argv[:header_search],
               progress_bar: @progress_bar
        transform TransformDropIfMosaicNotInt, mosaic_col: argv[:header_search]
        transform TransformCleanUnits
        transform TransformElementCostType
        transform TransformParseCostCentre
        # destination OutputCSV, filename: './out/b13-processed-' + Time.now.strftime("%m-%d-%Y.%H.%M.%S") + '.csv'
        destination OutputActiveRecords, progress_bar: @progress_bar
      end
    )
    puts "...Finished!"
  end
end
