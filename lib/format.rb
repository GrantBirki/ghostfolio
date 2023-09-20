# frozen_string_literal: true

require "csv"

class Format
  # soured from: https://github.com/ghostfolio/ghostfolio/blob/c511ec7e33123679490b36495d9ca7a09f04d329/apps/client/src/app/services/import-activities.service.ts#L16-L30
  def initialize(path)
    @path = path
    @translations = {
      date: {
        inputs: ["Date"],
        output: "date"
      },
      fee: {
        inputs: ["Fee", "Fees & Comm"],
        output: "fee"
      },
      quantity: {
        inputs: ["Quantity"],
        output: "quantity"
      },
      symbol: {
        inputs: ["Symbol", "Ticker"],
        output: "symbol"
      },
      type: {
        inputs: ["Action"],
        output: "type"
      },
      unit_price: {
        inputs: ["Price"],
        output: "price"
      }
    }

    @csv = load_csv
  end

  # Write the CSV file to the disk
  def write!
    puts "📁 writing formatted csv file: #{@path}"
    File.open(@path.gsub(".csv", "_formatted.csv"), "w") do |f|
      f.write(@csv.to_csv)
    end
  end

  # Helper function that reads the CSV file and translates all the headers
  # it writes the new csv file to the same directory as the original file but with _formatted appended to the file name
  def translate!
    puts "⏩ translating headers..."
    # loop through each header, if it can be translated from one of the 'inputs' value to an 'output' do so
    formatted_headers = []
    @csv.headers.each do |header|
      # loop through all the translations looking for a match
      match_found = false
      @translations.each do |_key, value|
        next unless value[:inputs].include?(header)

        formatted_headers << value[:output]
        match_found = true
        break
      end

      # if no match was found, just use the original header
      formatted_headers << header unless match_found
    end

    # construct a new CSV table that has the same data as the old one, but uses the new headers in their place
    @csv = CSV::Table.new(@csv.map { |row| CSV::Row.new(formatted_headers, row.fields) })

    return @csv
  end

  private

  def load_csv
    puts "📁 loading csv file: #{@path}"
    CSV.read(@path, headers: true)
  end
end
