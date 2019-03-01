
DEBUG = false
class InputParser
  attr_accessor :photos
  def initialize(file)
    @file_path = file
    @photos = []
    @tags_h = {}
  end
  def parse!
      file = File.open(@file_path,"r")
      tags = []

      File.foreach(@file_path).with_index do |line,i|
          next if i == 0
          #H 3 cat beach sun
          tmp = line.split(" ")
          #tmp[2..-1].each{|x| @tags_h[x] = 1}
          photo = {id: i-1,  hv: tmp[0], tags: tmp[2..-1]}
          @photos << photo
      end
    return @tags_h
  end
end

class Slide
  attr_accessor :tags, :ids
  def initialize(dict_tags)
    @dict_tags = dict_tags
    @tags = []
    @ids  = []
  end
  def add_photo(tags:, id:)
    @tags+=tags
    @ids << id
  end
  def to_s
    "#{self.ids} #{self.tags}"
  end
end

class SlideShow
  attr_accessor :slides
  def initialize
    @slides = []
    @sorted_slides = []
    @tags = {}
  end
  def add_slide(s)
    @slides << s
  end
  def export(filepath)
    file = File.open("./#{filepath}", 'w')
    file.puts @sorted_slides.size
    @sorted_slides.each do |x|
      file.puts x.ids.join " "
    end
    file.close
  end

  def sort!

    slot = @slides.length / 10
    threads = []
    10.times do |i|
      threads << Thread.new  {sort(i,slot*(i+1))}
      end
      threads.each { |thr| thr.join }
  end

  def sort(from,to)
    all_slide = @slides[from..to]
    sorted_slide = [all_slide.pop]

    while all_slide.count > 0
      puts "rimangono #{all_slide.count}"
      slide1 = sorted_slide.last
      slide2 = all_slide.first
      actual_score = score(slide1,slide2)
      all_slide.each do |slide_x|
        break if actual_score > (slide1.tags.length / 2) - 1
        x_score = score(slide1,slide_x)
        if x_score > actual_score
          actual_score = x_score
          slide2 = slide_x
        end

      end
      sorted_slide.push(slide2)
      all_slide.delete(slide2)
      puts "rimangono #{all_slide.count}"
    end
    @sorted_slides += sorted_slide
  end
  def score(slide1,slide2)

      in_comune = slide1.tags & slide2.tags
      solo_1    = slide1.tags - slide2.tags
      solo_2    = slide2.tags - slide1.tags
      test_score = [solo_1.length,solo_2.length,in_comune.length]
      test_score.min
  end
  def final_score()
    tot = 0
    0.upto(@sorted_slides.size-1) do |i|
      slide1=@sorted_slides[i]
      slide2=@sorted_slides[i+1]
      tot += score(slide1,slide2)
    end
  end


end

class SlideBuilder
  attr_accessor :photos, :slide_shows
  def initialize(photos)
    @photos = photos
    @slides = []
    @slide_shows = []

  end

  def build!
    vertical_photos = []
    horizontal_slides = SlideShow.new

    @photos.each do |ph|
      if ph[:hv] == "H"
        slide = Slide.new({})
        slide.add_photo(tags: ph[:tags], id: ph[:id])
        horizontal_slides.add_slide slide
      else
        vertical_photos << ph
      end
    end
    n = vertical_photos.length - 1 # n * (n-1) / n
    if n < 0
      @slide_shows = [horizontal_slides]
      return
    end
    @slide_shows = Array.new(n)
    n.times do |i|
      @slide_shows[i] = horizontal_slides
    end

    counter = 0

    vertical_photos.combination(2).each do |photos|
      n = vertical_photos.size - 1
      s = Slide.new({})
      s.add_photo(tags: photos.first[:tags], id: photos.first[:id])
      s.add_photo(tags: photos.last[:tags], id: photos.last[:id])
      @slide_shows[counter % n].add_slide s
      counter = counter + 1
    end
  end
end


file1="a_example.txt"
file2="b_lovely_landscapes.txt"
file3="c_memorable_moments.txt"
file4="d_pet_pictures.txt"
file5="e_shiny_selfies.txt"

#[file1,file2,file3,file4,file5].each do |input_file|
[file5].each do |input_file|
  ip = InputParser.new(input_file)
  ip.parse!
  sb = SlideBuilder.new(ip.photos)
  sb.build!
  sb.slide_shows.each_with_index do |slide_show,i|
    slide_show.sort!
    slide_show.export("out/#{input_file}_#{slide_show.final_score}.out")
  end
end