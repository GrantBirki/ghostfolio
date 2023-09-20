# frozen_string_literal: true

module Format
  class Translations
    # soured from: https://github.com/ghostfolio/ghostfolio/blob/c511ec7e33123679490b36495d9ca7a09f04d329/apps/client/src/app/services/import-activities.service.ts#L16-L30
    def initialize
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
          inputs: ["Type"],
          output: "type"
        },
        unit_price: {
          inputs: ["Price"],
          output: "price"
        }
      }
    end
  end
end
