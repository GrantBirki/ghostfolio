# frozen_string_literal: true

require_relative "../../lib/format"

# Get the first cli argument which is the file path
CSV_INPUT_PATH = ARGV[0]

class FormatCLI
  def initialize
    @path = CSV_INPUT_PATH
    @format = Format.new(@path)
  end

  def run
    @format.translate!
    @format.add_required_headers!
    @format.schwab_formatting!
    @format.write!
  end
end

FormatCLI.new.run
