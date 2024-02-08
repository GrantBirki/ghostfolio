# frozen_string_literal: true

require "faraday"
require "time"

module HistoricalData
  FUNDS = [
    "CRMAX",
    "FDGRX",
    "FSMVX",
    "VFFSX"
  ].freeze
  FUND_START_DATE = 1_459_209_600
  OUTPUT_DIR = "lib/historical_data"

  def self.fetch_all
    FUNDS.each do |fund|
      # Define the base URL
      base_url = "https://query1.finance.yahoo.com/v7/finance/download/#{fund}"

      # Define the parameters
      params = {
        period1: FUND_START_DATE,
        period2: Time.now.to_i,
        interval: "1d",
        events: "history",
        includeAdjustedClose: "true"
      }

      # Create a new Faraday connection
      conn = Faraday.new

      # Send a GET request
      response = conn.get do |req|
        req.url base_url
        req.params = params
      end

      # Save the response body to a CSV file
      File.open("#{OUTPUT_DIR}/#{fund}.csv", "w") { |file| file.write(response.body) }
    end
  end
end
