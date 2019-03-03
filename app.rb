
DEBUG = false
class InputParser
  attr_accessor :hphotos,:vphotos, :tags
  def initialize(file)
    @file_path = file
    @hphotos = {}
    @vphotos = {}
    @tags = {}
  end
  def parse!
      file = File.open(@file_path,"r")
      tags = []

      File.foreach(@file_path).with_index do |line,i|
          next if i == 0
          #H 3 cat beach sun
          tmp = line.split(" ")
          photo = {id: i-1,  hv: tmp[0], tags: tmp[2..-1], tag_num: tmp[2..-1].size}
          photo[:tags].each do |x|
            @tags[x] ||= {num: 0, v_ids: [], h_ids: []}
            if photo[:hv]=="H"
              @hphotos[photo[:id]] = photo
              @tags[x][:num] += 1
              @tags[x][:h_ids] << photo[:id]
            else
              @vphotos[photo[:id]] = photo
              @tags[x][:num] += 1
              @tags[x][:v_ids] << photo[:id]
            end
          end

      end
  end
end

class Slide
  attr_accessor :tags, :ids, :tag_num
  def initialize(photo)
    @tags = []
    @ids  = []
    @tag_num = 0
    add_photo(photo)
  end
  def add_photo(photo )
    return if photo.nil?
    @tags+=photo[:tags]
    @tags.uniq!
    @ids << photo[:id]
    @tag_num = @tags.count
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
    file.puts @slides.size
    @slides.each do |x|
      file.puts x.ids.join " "
    end
    file.close
  end

  def sort!
    @slides=@slides.sort_by { |s |s.tag_num  }
    th_num = 10
    if @slides.length < th_num
      return sort(0,@slides.length)
    end
    slot = (@slides.length / th_num).to_i
    puts "slot is: #{slot}"
    threads = []
    th_num.times do |i|
      threads << Thread.new  {sort(slot*i,slot*(i+1))}
    end
    threads.each { |thr| thr.join }
    @slides = @sorted_slides
  end

  def sort(from,to)
    return if from > @slides.length
    return if to > @slides.length
    puts "start sort from #{from} to #{to}"
    all_slide = @slides[from...to]
    sorted_slide = [all_slide.pop]

    while all_slide.count > 0
      puts "rimangono #{all_slide.count}"
      slide1 = sorted_slide.last
      slide2 = all_slide.first
      actual_score = score(slide1,slide2)
      all_slide.each do |slide_x|
        break if actual_score > (slide1.tag_num / 2) - 1
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
    return 0 if slide1.nil?
    return 0 if slide2.nil?
      in_comune = slide1.tags & slide2.tags
      return 0 if in_comune == 0
      solo_1    = slide1.tags - slide2.tags
      return 0 if solo_1 == 0
      solo_2    = slide2.tags - slide1.tags
      return 0 if solo_2 == 0
      [solo_1.length,solo_2.length,in_comune.length].min
  end
  def final_score()
    tot = 0
    0.upto(@slides.size-1) do |i|
      slide1=@slides[i]
      slide2=@slides[i+1]
      tot += score(slide1,slide2)
    end
    tot
  end


end

class SlideBuilder
  attr_accessor :slide_shows
  def initialize(hphotos:nil, vphotos:nil, tags:nil)
    @hphotos = hphotos
    @vphotos = vphotos
    @tags = tags
    @slide_shows = []
  end

  def find_best_match(slide, photos)
    #time_start = Time.now
    best_id={score: 0, photo: nil}
    photos.each do |x|
      score = [(slide.tags & x[:tags]).size, (slide.tags - x[:tags]).size, (x[:tags]-slide.tags).size ]
      #puts " #{Thread.current.object_id}  ... "
      if score.min > ((slide.tag_num / 2) - 1)
        best_id = {score: score.min, photo: x}
        #puts "#{Thread.current.object_id} selecting photos with same tags #{Time.now - time_start}"
        return best_id
      elsif score.min >= best_id[:score]
        best_id = {score: score.min, photo: x}
      end
    end
    #puts "#{Thread.current.object_id} selecting photos with same tags #{Time.now - time_start}"
    return best_id
  end

  def build!(name)
    vertical_photos = []
    horizontal_slides = SlideShow.new
    # una foto H che ha 4 tag darà il massimo punteggio
    # con una altra foto da 4 tag con 2 soli tag in comune
    # una voto verticale che ha 4 tag va accoppiata con un'altra con
    # 4 tag diversi e poi associata con una che ha la metà dei tag

    all_ids = @vphotos.keys
    all_ids += @hphotos.keys
    s = Slide.new(nil)
    photo = @hphotos.values.max_by{ |x| x[:tag_num]}

    if photo.nil?
      photo = @vphotos.values.max_by(2){ |x| x[:tag_num]}
      s.add_photo(photo.first)
      s.add_photo(photo.last)
      all_ids.delete(photo.first[:id])
      all_ids.delete(photo.last[:id])
      @vphotos.delete(photo.first[:id])
      @vphotos.delete(photo.last[:id])
    else
      s.add_photo(photo)
      all_ids.delete(photo[:id])
      @hphotos.delete(photo[:id])
    end

    horizontal_slides.add_slide(s)

    while all_ids.any?
      puts "#{name} mancano #{all_ids.size}"
      s1=nil
      s2=nil
      th1 = Thread.new do
        s1=nil
        h_photo_ids = s.tags.map{|x| @tags[x][:h_ids]}.flatten.uniq
        top_h_photos_with_same_tags = h_photo_ids.map{|id| @hphotos[id]}.compact.sort_by { |x | x[:tag_num]}.reverse
        best_id = find_best_match(s, top_h_photos_with_same_tags)
        if best_id[:photo]
          s1 = Slide.new(best_id[:photo])
        end

      end
      th1.join

      th2 = Thread.new do
        s2=nil

        v_photo_ids = s.tags.map{|x| @tags[x][:v_ids]}.flatten

        photo_v_same_tags = v_photo_ids.map{|id| @vphotos[id]}.compact
        best_id={similar_tags: 0, photo: nil}
        photo_v_same_tags.each do |x|
          if (s.tags & x[:tags]).size < (s.tag_num / 2)
            best_id={similar_tags: (s.tags & x[:tags]).size, photo: x}
            break
          end
          if (s.tags & x[:tags]).size >= best_id[:similar_tags]
            best_id={similar_tags: (s.tags & x[:tags]).size, photo: x}
          end
        end

        if !best_id[:photo].nil?
          s2 = Slide.new(best_id[:photo])
          photo_v_no_tags = @vphotos.values.select{|x| !v_photo_ids.include?(x[:id])}.compact.sort_by { |x | x[:tag_num]}.reverse
          best_id=find_best_match(s, photo_v_no_tags)
          if best_id[:photo]
            s2.add_photo(best_id[:photo])
          else
            s2=nil
          end
        end
      end

      th2.join

      score1,score2 = 0
      th_sc1 = Thread.new {score1=horizontal_slides.score(s,s1)}
      th_sc2 = Thread.new {score2=horizontal_slides.score(s,s2)}

      if s1
        th_sc1.join
        th_sc2.join
        if score1 >= score2
          horizontal_slides.add_slide(s1)
          s1.ids.each do |x|
            @hphotos.delete(x)
            all_ids.delete(x)
          end
          s=s1
          next
        end
      end
      if s2
        horizontal_slides.add_slide(s2)
        s2.ids.each do |x|
          @vphotos.delete(x)
          all_ids.delete(x)
        end
        s=s2
      else
        all_ids = []
      end
    end
    @slide_shows = [horizontal_slides]
  end
end


file1="a_example.txt"
file2="b_lovely_landscapes.txt"
file3="c_memorable_moments.txt"
file4="d_pet_pictures.txt"
file5="e_shiny_selfies.txt"


threads = []
my_path ="out/#{Time.now.to_i}"
Dir.mkdir my_path
[file1,file2,file3,file4,file5].each do |input_file|
  ip = InputParser.new(input_file)
  ip.parse!
  th = Thread.new do
    sb = SlideBuilder.new(vphotos: ip.vphotos,hphotos: ip.hphotos, tags: ip.tags)
    sb.build!(input_file)
    sb.slide_shows.each_with_index do |slide_show,i|
      #slide_show.sort!
      slide_show.export("#{my_path}/#{input_file}_#{slide_show.final_score}.out")
    end
  end
  #th.join
  threads << th
end
threads.map {|th| th.join }
