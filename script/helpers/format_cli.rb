# frozen_string_literal: true

require_relative "../../lib/format"

# Get the first cli argument which is the file path
CSV_INPUT_PATH = ARGV[0]

class FormatCLI
  def initialize
    @format = Format.new
  end

  def run
    puts "Formatting #{CSV_INPUT_PATH}..."
  end
end

FormatCLI.new.run
