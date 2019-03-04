require 'enumerator'

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
  def score(slide2)
    return 0 if slide2.nil?
    in_comune = @tags & slide2.tags
    return 0 if in_comune == 0
    solo_1    = @tags - slide2.tags
    return 0 if solo_1 == 0
    solo_2    = slide2 - @tags
    return 0 if solo_2 == 0
    [solo_1.length,solo_2.length,in_comune.length].min
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
  def remove_last_slide
    @slides.pop
    @slides.last
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
    all_slide = @slides[from...to]
    sorted_slide = [all_slide.pop]

    while all_slide.count > 0
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
  def initialize(photos:nil, tags:nil, name: nil)
    @photos = photos
    @tags = tags
    @name = name
    @slide_shows = nil
  end


  def find_best_match(slide, photos, excluded_ids=[])
    time_start = Time.now.to_f
    best_id={score: -1, photo: nil, max_value: false}
    photos.each do |x|
      next if excluded_ids.include? x[:id]
      score = [(slide.tags & x[:tags]).size, (slide.tags - x[:tags]).size, (x[:tags]-slide.tags).size ]
      best_id ||= {score: score.min, photo: x, max_value: false}
      if score.min > ((slide.tag_num / 2) - 1)
        best_id = {score: score.min, photo: x, max_value: true}
        return best_id
      #elsif (i > photos.size / 3) && (score.min > ((slide.tag_num / 2)*0.5))
      #  best_id = {score: score.min, photo: x}
      #  return best_id
      elsif score.min >= best_id[:score]
        best_id = {score: score.min, photo: x, max_value: false}
      end
    end
    total_time = Time.now.to_f - time_start
    return best_id
  end

  def build!
    @slide_shows  = organize_slide( @photos)
  end

  def organize_slide (photos)
    vphotos = {}
    hphotos = {}
    photos.each do |k,v|
      if v[:hv]=="V"
        vphotos[k]=v
      else
        hphotos[k]=v
      end
    end

    all_ids = []
    all_ids += vphotos.keys if vphotos
    all_ids += hphotos.keys if hphotos

    s = Slide.new(nil)
    slideshow = SlideShow.new

    return slideshow if all_ids.empty?

    photo = hphotos.values.max_by{ |x| x[:tag_num]} # parto da quella con più tag

    if photo.nil?
      #se non ho la prima orinzonale, prendo le prime 2 verticali
      photo = vphotos.values.max_by(2){ |x| x[:tag_num]}
      s.add_photo(photo.first)
      s.add_photo(photo.last)
      all_ids.delete(photo.first[:id])
      all_ids.delete(photo.last[:id])
      vphotos.delete(photo.first[:id])
      vphotos.delete(photo.last[:id])
    else
      s.add_photo(photo)
      all_ids.delete(photo[:id])
      hphotos.delete(photo[:id])
    end

    slideshow.add_slide(s)
    start_time = Time.now

    #ciclo alla ricerca del best match tra tutte le altre foto
    while all_ids.any?
      elapsed = Time.now - start_time
      score1={score: -1, photo: nil, max_value: false}
      score2={score: -1, photo: nil, max_value: false}
      s1=nil
      s2=nil
      #prendo tutti gli id delle foto H che hanno uno dei tag della slide corrente
      h_photo_ids = s.tags.map{|x| @tags[x][:h_ids]}.flatten.uniq

      #e prendo tutte le foto. ho bisogno di almeno un match
      top_h_photos_with_same_tags = h_photo_ids.map{|id| hphotos[id]}.compact

      #cerco la slide migliore
      score1 = find_best_match(s, top_h_photos_with_same_tags)
      if score1  && score1[:photo]
        s1 = Slide.new(score1[:photo])
        #se ha un punteggio massimo, passo avanti
        if score1[:max_value]
          slideshow.add_slide(s1)
          s1.ids.each do |x|
            #cancello le foto usate
            hphotos.delete(x)
            all_ids.delete(x)
          end
          #aggiorno il puntatore
          s=s1
          #riparte il ciclo
          next
        end
      end

      # ho la s1 (forse) ma non è il massimo. cerco tra le verticali

      #id delle foto con gli stessi tag della slide corrente
      v_photo_ids = s.tags.map{|x| @tags[x][:v_ids]}.flatten

      #array delle photo con gli stessi tag
      photo_v_same_tags = v_photo_ids.map{|id| vphotos[id]}.compact

      photo_v_same_tags.each do |x|
        #per ogni foto costruisco una slide e vedo se trovo una copia
        # con il punteggio massimo
        s2 = Slide.new(x)
        tmp_score2=find_best_match(s, vphotos.values , s2.ids )
        if tmp_score2[:max_value]
          score2=tmp_score2
          s2.add_photo(score2[:photo])
          slideshow.add_slide(s2)
          s2.ids.each do |x|
            vphotos.delete(x)
            all_ids.delete(x)
          end
          break
        elsif tmp_score2[:score] > score2[:score]
          score2=tmp_score2
        end
      end
      if score2[:max_value]
        next
      end
      if score2[:photo]
        s2.add_photo(score2[:photo])
      else
        s2 = nil
      end
      #se sono qui ho i due score da confonrare

      #se sono entrambi nulli, non ho trovato più nulla.. esco
      if score1[:photo].nil? && score2[:photo].nil?
        #prendo una slide a caso e riparto
        if hphotos
          x = hphotos.first
          s1 = Slide.new(x[1])
          slideshow.add_slide(s1)
          s1.ids.each do |x|
            hphotos.delete(x)
            all_ids.delete(x)
          end
          s=s1
          next
        else
          x = vphotos.first
          s2 = Slide.new(x[1])
          hphotos.delete(x)
          all_ids.delete(x)
          x = vphotos.first
          s2 = Slide.new(x[1])
          hphotos.delete(x)
          all_ids.delete(x)
          slideshow.add_slide(s2)
          s2.ids.each do |x|
            vphotos.delete(x)
            all_ids.delete(x)
          end
          s=s2
          next
        end
      elsif score1[:score] > score2[:score]
        #ho solo score 1 oppure score1 > score2
        slideshow.add_slide(s1)
        s1.ids.each do |x|
          hphotos.delete(x)
          all_ids.delete(x)
        end
        s=s1
      else
        slideshow.add_slide(s2)
        s2.ids.each do |x|
          vphotos.delete(x)
          all_ids.delete(x)
        end
        s=s2
      end
      puts "#{@name} done #{slideshow.slides.size} mancano #{all_ids.size} - #{elapsed} sec  #{elapsed/slideshow.slides.count} sec/photo"
    end
    return slideshow
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
  fork do
    ip = InputParser.new(input_file)
    ip.parse!
    photos = ip.vphotos.merge(ip.hphotos)
    sb = SlideBuilder.new(photos: photos, tags: ip.tags, name: input_file)
    sb.build!
    #sb.slide_shows.sort!
    sb.slide_shows.export("#{my_path}/#{input_file}_#{sb.slide_shows.final_score}.out")
  end
  #th.join
  #threads << th
end
#threads.map {|th| th.join }
