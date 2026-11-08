class CreateExchangeRates < ActiveRecord::Migration[8.0]
  def change
    create_table :exchange_rates do |t|
      t.string :currency, null: false, limit: 3
      t.integer :year, null: false
      t.decimal :rate_to_usd, null: false, precision: 18, scale: 8
      t.integer :version, null: false
      t.string :reason, null: false
      t.string :set_by, null: false
      t.timestamps
    end
    add_index :exchange_rates, %i[currency year version], unique: true
  end
end
