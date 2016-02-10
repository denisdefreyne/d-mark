require "../d-mark"

data = File.read(ARGV[0]).strip

parser = DMark::Parser.new(data)
begin
  result = parser.parse
  result.each { |r| puts r.to_s(true) ; puts }
rescue e
  case e
  when DMark::Parser::ParserError
    line = data.lines[e.line_nr]

    puts "\e[31mError:\e[0m #{e.message}}"
    puts
    puts line
    puts "\e[31m" + " " * e.col_nr + '↑' + "\e[0m"
    exit 1
  else
    raise e
  end
end
