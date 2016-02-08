require "../d-mark"

data = File.read(ARGV[0])

result = DMark::Px.lone_block.parse(data, 0)
case result
when DMark::ParseSuccess
  puts "Success!"
  exit 0
when DMark::ParseFailure
  left = [0, result.pos - 37].max
  right = result.pos + 37

  puts "\e[31mError:\e[0m #{result.message}"
  puts
  puts data.gsub("\n", "↲")[left..right]
  puts "\e[31m" + " " * result.pos + '↑' + "\e[0m"
  exit 1
end
