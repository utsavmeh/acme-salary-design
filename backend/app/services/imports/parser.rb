require "csv"
require "roo"

module Imports
  # Reads a .csv or .xlsx file into rows of text. Nothing is interpreted here: every cell becomes a
  # string (dates as YYYY-MM-DD) and the checking happens in RowValidator.
  class Parser
    MAX_ROWS = 50_000
    Row = Struct.new(:number, :values, keyword_init: true) # number = line in the file (header is line 1)

    def self.call(path, filename) = new(path, filename).call

    def initialize(path, filename)
      @path = path
      @extension = File.extname(filename.to_s).downcase
    end

    def call
      table = case @extension
              when ".csv" then csv_table
              when ".xlsx" then xlsx_table
              else raise AppErrors::BadRequest, "Only .csv and .xlsx files can be imported"
              end
      header, *lines = table
      raise AppErrors::BadRequest, "The file is empty" if header.nil?
      raise AppErrors::BadRequest, "The file has more than #{MAX_ROWS} rows" if lines.size > MAX_ROWS

      names = header.map { |h| h.to_s.strip.downcase.gsub(/\s+/, "_") }
      lines.each_with_index.filter_map do |cells, index|
        next if cells.all?(&:blank?)

        Row.new(number: index + 2, values: names.zip(cells.map { |c| cell_text(c) }).to_h)
      end
    end

    private

    def csv_table
      CSV.read(@path, encoding: "bom|utf-8")
    rescue CSV::MalformedCSVError => e
      raise AppErrors::BadRequest, "The CSV file is malformed: #{e.message}"
    end

    def xlsx_table
      sheet = Roo::Excelx.new(@path).sheet(0)
      return [] if sheet.last_row.nil?

      (1..sheet.last_row).map { |i| sheet.row(i) }
    rescue Zip::Error, ArgumentError, RuntimeError => e
      raise AppErrors::BadRequest, "The Excel file could not be read: #{e.message}"
    end

    def cell_text(cell)
      case cell
      when nil then ""
      when Date then cell.iso8601
      when DateTime, Time then cell.to_date.iso8601
      when Float then cell == cell.to_i ? cell.to_i.to_s : cell.to_s
      else cell.to_s.strip
      end
    end
  end
end
