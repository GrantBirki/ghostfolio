# frozen_string_literal: true

require_relative "../../lib/format"
require_relative "../../lib/historical_data_fetcher"

# Get the first cli argument which is the file path
CSV_INPUT_PATH = ARGV[0]
ACCOUNT_ID = ARGV[1]

class FormatCLI
  def initialize
    @path = CSV_INPUT_PATH
    @account_id = ACCOUNT_ID
    @format = Format.new(@path, @account_id)
  end

  def run
    # fetch historical data
    HistoricalData.fetch_all

    # pre-processing
    @format.fidelity_pre_formatting!

    # header translation
    @format.translate!
    @format.add_required_headers!

    # row translation
    @format.type_translation!
    @format.price_translation!

    # platform specific formatting
    @format.schwab_formatting!
    @format.wex_formatting!
    @format.robinhood_formatting!
    @format.fidelity_formatting!

    @format.summary_display

    # write the formatted csv file to the disk
    @format.write!
  end
end

FormatCLI.new.run
