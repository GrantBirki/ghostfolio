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
        output: "type",
        sub_translations: {
          "Reinvest Shares": "buy",
          "Reinvest Dividend": "dividend",
          "Journaled Shares": "buy"
        }
      },
      unit_price: {
        inputs: ["Price"],
        output: "price"
      }
    }

    @required_headers = {
      currency: {
        default: "USD"
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

  # A helper function to add any required headers that are missing from the CSV file
  # If a required header is missing, it will be added to the CSV file with the default value for all rows
  def add_required_headers!
    puts "🔍 adding required headers..."
    @required_headers.each do |header, value|
      @csv.headers << header.to_s unless @csv.headers.include?(header.to_s)
      @csv.each do |row|
        row[header] = value[:default] unless row[header]
      end
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

  # Helper function to translate the 'type' column
  def type_translation!
    @csv.each do |row|
      # loop through all the type sub translations looking for a match
      @translations[:type][:sub_translations].each do |key, value|
        row_value = row[@translations[:type][:output]].to_s
        key_string = key.to_s

        # skip this row if the value doesn't match the key
        next unless row_value == key_string

        # update the row with the new value and break out of the loop
        row[@translations[:type][:output]] = value
        break
      end
    end
  end

  # Helper function to specifically format the Schwab CSV file
  def schwab_formatting!
    date_regex = %r{\d{2}/\d{2}/\d{4}}

    # loop through each 'date' row of the CSV
    @csv.each do |row|
      match = row[@translations[:date][:output]].match(date_regex)
      next unless match

      new_date = match[0]
      # update the row with the new date
      row[@translations[:date][:output]] = new_date
    end

    # remove any rows that contain "Transactions Total"
    @csv.delete_if { |row| row[@translations[:date][:output]] == "Transactions Total" }

    # convert all 'date' rows to the following format: dd/MM/yyyy
    @csv.each do |row|
      row[@translations[:date][:output]] =
        Date.strptime(row[@translations[:date][:output]], "%m/%d/%Y").strftime("%d/%m/%Y")
    end

    # if the 'fee' field is null, set it to zero
    @csv.each do |row|
      if row[@translations[:fee][:output]].nil? || row[@translations[:fee][:output]].empty? || row[@translations[:fee][:output]] == ""
        row[@translations[:fee][:output]] =
          0
      end
    end

    # remove the entire row if the 'type' field contains any of the following values
    discard_type_fields = [
      "Bank Interest",
      "MoneyLink Transfer",
      "Journal"
    ]

    @csv.delete_if { |row| discard_type_fields.include?(row[@translations[:type][:output]].to_s) }
  end

  private

  def load_csv
    puts "📁 loading csv file: #{@path}"
    CSV.read(@path, headers: true)
  end
end
