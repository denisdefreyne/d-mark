require "../d-mark"

data = File.read(ARGV[0]).strip

parser = DMark::Parser.new(data)
begin
  result = parser.parse
  result.each { |r| puts r.to_s(true) ; puts }
rescue e
  case e
  when DMark::Parser::ParserError
    left = [0, parser.pos - 37].max
    right = parser.pos + 37

    puts "\e[31mError:\e[0m #{e.message || "parse error at position #{parser.pos}"}"
    puts
    puts data.gsub("\n", "␤")[left..right]
    puts "\e[31m" + " " * parser.pos + '↑' + "\e[0m"
    exit 1
  else
    raise e
  end
end
