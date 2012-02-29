
#require 'rubygems'

#require '/home/mulroony/ruby/rubygems-1.3.5/bin/gem'

RAILS_ENV='production'
require '/rails/ebi/config/environment'

require 'rvg/rvg'
include Magick

def drawcountry(crop = "miscanthus")
  p crop

  countyAvg = Struct.new(:OBJECTID,:Join_Count,:TARGET_FID,:COUNTY_NAME,:STATE_NAME,:STATE_FIPS,:CNTY_FIPS,:FIPS,:Avg_lat,:Avg_lon,:Avg_yield)

  f = File.new "/rails/ebi/db_backups/location_yields/miscanthus_county_avg_yield.csv"

  f.gets

  county_avgs = []

  f.each_line do |line|
    county_avgs << countyAvg.new(*line.chomp.split(","))
  end

  f.close

  p "Finished reading file"

  time = Time.now


  totlatmax = CountyBoundary.first(:order => "lat desc") .lat.to_f
  totlatmin = CountyBoundary.first(:order => "lat asc").lat.to_f
  totlngmax = CountyBoundary.first(:order => "lng desc").lng.to_f
  totlngmin = CountyBoundary.first(:order => "lng asc").lng.to_f

  totlngdiff = (totlngmax-totlngmin).abs
  totlatdiff = (totlatmax-totlatmin).abs

  ratio = totlngdiff/totlatdiff

  color_range = {}
  avgs = county_avgs.collect { |x| x.Avg_yield.to_f }
  color_range[:max] = avgs.max.to_f
  color_range[:min] = avgs.min.to_f

  p "max: #{color_range[:max]}"
  p "min: #{color_range[:min]}"

  # Five Colors
  color_range[:increment] = (color_range[:max] - color_range[:min])/120

  RVG::dpi = 600
  scale_list_buffer = Magick::ImageList.new
  scale_list_buffer << Magick::Image.new(30, 5) { self.fill = 'none' }
  scale_list_buffer << Magick::Image.new(30, 240, Magick::GradientFill.new(0,0,240,0,"hsl(240,100,50)","hsl(360,100,50)"))
  scale_list_buffer[1].opacity = Magick::MaxRGB/2 
  scale_list = Magick::ImageList.new
  scale_list << scale_list_buffer.append(true)
  scale_list << Magick::Image.new(150, 250){ self.fill = 'none'  }
  txt = Draw.new

  txt.annotate(scale_list[1],0,0,5,10,"0.00"){
    self.font_family = 'Helvetica'
    self.pointsize = 12
    self.stroke = "#000000"
    self.fill = "#000000"
  }

  1.upto(6) do |_i|
    txt.annotate(scale_list[1],0,0,5,_i*40+5,"#{(_i*color_range[:max]/6).round(4)}"){
      self.font_family = 'Helvetica'
      self.pointsize = 12
      self.stroke = "#000000"
      self.fill = "#000000"
    }
  end
  
  scale_list.append(false).write("/rails/ebi/public/#{crop}-scale.png")

  p "Finished drawing scale"

  rvg = RVG.new((2*ratio).in, 2.in).viewbox(totlngmin,totlatmin,totlngdiff,totlatdiff) do |canvas|
    canvas.background_fill_opacity = 0.0

    canvas.g.translate(0, 0) do |head|
        head.circle(3).styles(:fill=>'black')
    end

    county_avgs.each do |_counties|
      censusid = County.first(:conditions => ["name like ? and state like ?",_counties.COUNTY_NAME.delete("\""),_counties.STATE_NAME.delete("\"")]).censusid rescue ''

      if censusid == ''
        p "#{_counties.FIPS}: #{_counties.OBJECTID} - #{_counties.COUNTY_NAME}, #{_counties.STATE_NAME}"
        p "----"
        next
      end

      avg = _counties.Avg_yield.to_f

      avg = 0.0 if avg.nil?

      c = CountyBoundary.find_by_sql("select lat,lng from county_boundaries where censusid = #{censusid}")

      c.delete_at(0)
      cc = c.collect {|x| "#{x.lng},#{x.lat}"}.join(" ")

      next if cc.length == 0
      
      if avg == 0.0
        color = "hsl(0,100,100)"
      else
        tmp = ((120*avg.to_f)/color_range[:max]).round(0)
        color = "hsl(#{240+tmp.to_i},100,50)"
      end

      county = RVG::Group.new do |_county|
        _county.path("M #{cc} Z").styles(:stroke_width => 0.0000000001, :fill_opacity => 0.5, :fill => "#{color}", :stroke_opacity => 0.0, :stroke => "#{color}")
      end
      canvas.use(county)
    end
  end
  img = rvg.draw
  img.flip!
  img.write("/rails/ebi/public/#{crop}.png")

  p "#{(Time.now - time).to_f}"
end

plant = ARGV[0]

if plant == "all"
  drawcountry("miscanthus")
  drawcountry("switchgrass")
  drawcountry("poplar")
else
  drawcountry(plant)
end

