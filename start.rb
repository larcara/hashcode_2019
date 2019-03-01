require_relative "./app.rb"

file1="a_example.txt"
file2="b_lovely_landscapes.txt"

input_file = file1

ip = InputParser.new(input_file)
ip.parse!
sb = SlideBuilder.new(ip.photos)
sb.build!

sb.slide_shows.each{|slide_show| slide_show.export("#{input_file}_#{slide_show.score}.out")}

