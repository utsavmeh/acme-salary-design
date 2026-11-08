# Spreadsheet programs run text that starts with = + - @ as a formula. A name such as
# "=HYPERLINK(...)" in an export could therefore attack whoever opens the file. Prefixing a
# quote makes the program treat it as plain text.
module CsvSanitizer
  DANGEROUS_START = /\A[=+\-@\t\r]/

  module_function

  def call(value)
    text = value.to_s
    text.match?(DANGEROUS_START) ? "'#{text}" : text
  end
end
