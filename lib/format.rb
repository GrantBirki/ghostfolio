# frozen_string_literal: true

require "csv"

class Format
  # soured from: https://github.com/ghostfolio/ghostfolio/blob/c511ec7e33123679490b36495d9ca7a09f04d329/apps/client/src/app/services/import-activities.service.ts#L16-L30
  def initialize(path, account_id)
    @account_id = account_id
    @path = path
    @translations = {
      date: {
        inputs: ["Date", "Activity Date"],
        output: "date"
      },
      fee: {
        inputs: ["Fee", "Fees & Comm"],
        output: "fee"
      },
      quantity: {
        inputs: ["Quantity", "Shares/Unit", "Units"],
        output: "quantity"
      },
      symbol: {
        inputs: ["Symbol", "Ticker", "Instrument", "Investment", "FundName"],
        output: "symbol"
      },
      type: {
        inputs: ["Action", "Trans Code", "Transaction Type", "TransName"],
        output: "type",
        sub_translations: {
          "Buy": "buy",
          "Sell": "sell",
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
      },
      accountid: {
        default: @account_id
      }
    }

    @csv = load_csv
  end

  # a helper function to display a summery of the CSV file in the terminal
  def summary_display
    total_stock_purchased = 0
    total_stock_sold = 0
    @csv.each do |row|
      total_stock_purchased += row[@translations[:quantity][:output]].to_f * row[@translations[:unit_price][:output]].to_f - row[@translations[:fee][:output]].to_f

      total_stock_sold += row[@translations[:quantity][:output]].to_f * row[@translations[:unit_price][:output]].to_f - row[@translations[:fee][:output]].to_f if row[@translations[:type][:output]] == "sell"
    end

    puts "\n=========================="
    puts "📊 csv file summary 📊"
    puts "💰 tranactions summary:"
    puts "  - total stock purchased: $#{total_stock_purchased}"
    puts "  - total stock sold: $#{total_stock_sold}"
    puts "==========================\n\n"
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

  def price_translation!
    # loop through each 'price' row of the CSV and remove any non-numeric characters
    @csv.each do |row|
      if row[@translations[:unit_price][:output]] =~ /\D/
        row[@translations[:unit_price][:output]] =
          row[@translations[:unit_price][:output]].gsub(/[^0-9.]/, "")
      end

      # remove non-numeric characters from the 'fee' row
      if row[@translations[:fee][:output]] =~ /\D/
        row[@translations[:fee][:output]] =
          row[@translations[:fee][:output]].gsub(/[^0-9.]/, "")
      end
    end
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

    # remove any 'quantity' rows that are empty
    @csv.delete_if do |row|
      row[@translations[:quantity][:output]].nil? || row[@translations[:quantity][:output]].empty? || row[@translations[:quantity][:output]] == ""
    end
  end

  def wex_formatting!
    # remove the 'Source' column from the CSV
    @csv.delete("Source")

    # delete all the rows with type 'Investment Purchase - Cash receipt'
    # I just don't know what these are
    @csv.delete_if { |row| row[@translations[:type][:output]].include?("Cash receipt") }

    # delete all type rows with 'Custodial Management'
    # ghostfolio doesn't support fees yet IIRC
    @csv.delete_if { |row| row[@translations[:type][:output]].include?("Custodial Management") }

    # skip cash withdrals on initial import ('Investment Withdrawal - Cash disbursement')
    @csv.delete_if { |row| row[@translations[:type][:output]].include?("Cash disbursement") }

    @csv.each do |row|
      if row[@translations[:symbol][:output]] == "AMERICAN FUNDS BALANCED FND R6"
        row[@translations[:symbol][:output]] =
          "RLBGX"
      end

      if row[@translations[:type][:output]] == "Investment Purchase"
        row[@translations[:type][:output]] =
          "buy"
      end

      if row[@translations[:type][:output]] == "Reinvested Dividend"
        row[@translations[:type][:output]] =
          "dividend"
      end

      next unless row[@translations[:type][:output]] == "Investment Withdrawal"

      row[@translations[:type][:output]] =
        "sell"

      # also convert the value from a negative to a positive
      row[@translations[:quantity][:output]] =
        row[@translations[:quantity][:output]].to_f.abs
    end
  end

  def robinhood_formatting!
    # remove the following columns from the csv
    @csv.delete("Process Date")
    @csv.delete("Settle Date")
    @csv.delete("Description")

    # delete "Amount" unless we are running in the fidelity mode
    @csv.delete("Amount") if ENV.fetch("FIDELITY", nil) != "true"

    # remove any rows in the "type" column that are set to the following:
    # i have no idea what these IDs mean 🤷
    types_to_remove = ["STC", "OEXP", "BTO", "SPL", "CONV", "STO", "OASGN", "SOFF", "BCXL"]
    @csv.delete_if { |row| types_to_remove.include?(row[@translations[:type][:output]].to_s) }
  end

  def fidelity_pre_formatting!
    return unless ENV.fetch("FIDELITY", nil) == "true"

    puts "🏃 running fidelity pre-formatting..."

    # reconstruct the csv table in the exact same way except with the Amount header changed to price
    new_headers = []
    @csv.headers.each do |header|
      header = "price" if header == "Amount"
      new_headers << header
    end

    @csv = CSV::Table.new(@csv.map { |row| CSV::Row.new(new_headers, row.fields) })
  end

  def fidelity_formatting!
    @csv.each do |row|
      # replace all symbol values that are VAN IS S&amp;P500 IDX TR with VFFSX
      if row[@translations[:symbol][:output]] == "VAN IS S&amp;P500 IDX TR" || row[@translations[:symbol][:output]] == "VANG 500 IDX IS SEL"
        row[@translations[:symbol][:output]] =
          "VFFSX"
      end

      # replace all symbol values that are FID GR CO POOL CL O with FDGRX
      if row[@translations[:symbol][:output]] == "FID GR CO POOL CL O" || row[@translations[:symbol][:output]] == "FID GR CO POOL CL S"
        row[@translations[:symbol][:output]] =
          "FDGRX"
      end

      # replace all symbol values that are SMID CAP VALUE ACCT with CRMAX
      if row[@translations[:symbol][:output]] == "SMID CAP VALUE ACCT"
        row[@translations[:symbol][:output]] =
          "CRMAX"
      end

      # replace all symbol values that are DFA SM/MD CAP VAL with FSMVX
      if row[@translations[:symbol][:output]] == "DFA SM/MD CAP VAL"
        row[@translations[:symbol][:output]] =
          "FSMVX"
      end

      # change all 'types' of 'Contributions' to 'buy'
      row[@translations[:type][:output]] = "buy" if row[@translations[:type][:output]] == "Contributions"

      # do the same as the above line but for 'Transfers'
      row[@translations[:type][:output]] = "buy" if row[@translations[:type][:output]] == "Transfers"
    end

    # if a rows 'type' is 'buy' but price,quantity are both 0 or variations of 0 (0.0, 0.00, or 0.000) remove the row
    @csv.delete_if do |row|
      if row[@translations[:type][:output]] == "buy" && row[@translations[:unit_price][:output]].to_f == 0.0 && row[@translations[:quantity][:output]].to_f == 0.0
        true
      else
        false
      end
    end

    # delete all 'type' rows that are of the following
    remove_rows = [
      "Exchange In",
      "Exchange Out",
      "Change on Market Value"
    ]

    @csv.delete_if { |row| remove_rows.include?(row[@translations[:type][:output]].to_s) }

    # for each row in the csv, loop through it and replace the 'price' field with the resulting data from the 'historical_stock_price' method
    return unless ENV.fetch("FIDELITY", nil) == "true"

    @csv.each do |row|
      price = historical_stock_price(row[@translations[:symbol][:output]], row[@translations[:date][:output]])

      # update the row with the new price
      row[@translations[:unit_price][:output]] = price
    end
  end

  private

  # helper method to get the historical stock price for a given symbol and date
  # CSV's with 5 year historical data are available from Yahoo Finance
  def historical_stock_price(symbol, date)
    parsed_date = Date.strptime(date, "%d/%m/%Y")
    # covert the date to YYYY-MM-DD format
    parsed_date = parsed_date.strftime("%Y-%m-%d")

    # load the following CSV file into memory ex: historical_data/<TICKER>.csv
    historical_csv_data = CSV.read("lib/historical_data/#{symbol}.csv", headers: true)

    # loop through each row in the CSV until we find a matching date
    historical_csv_data.each do |row|
      next unless row["Date"] == parsed_date

      return row["Close"]
    end
  end

  def load_csv
    # before we load the CSV, make a best effort attempt to strip out any junk
    # open the file and remove any whitespace / newlines at the beginning and end of the file
    # Open the file in read mode, read it into memory, and close it
    file_content = File.read(@path)

    # remove any whitespace / newlines at the beginning and end of the file
    file_content.strip!

    # remove any lines that contain "Plan name:,"
    file_content = file_content.split("\n").reject { |line| line.include?("Plan name:,") }.join("\n")
    # remove any lines that contain "Date Range,"
    file_content = file_content.split("\n").reject { |line| line.include?("Date Range,") }.join("\n")

    # remove any new lines from the beginning of the file
    file_content = file_content.split("\n").reject { |line| line == "" }.join("\n")

    # Open the file in write mode, write the modified content, and close it
    File.write(@path, file_content)

    puts "📁 loading csv file: #{@path}"
    CSV.read(@path, headers: true)
  end
end
