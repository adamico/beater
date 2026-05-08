# app/map_generator.rb
require 'app/gmm_parser.rb'
require 'app/wall_shape.rb'

module MapGenerator
  def self.generate_if_needed(gmm_path, rb_path)
    needs_generation = false
    
    begin
      gmm_stat = $gtk.stat_file(gmm_path)
      rb_stat = $gtk.stat_file(rb_path)
      
      if rb_stat.nil?
        needs_generation = true
      elsif gmm_stat && gmm_stat[:mtime_ms] && rb_stat[:mtime_ms]
        needs_generation = gmm_stat[:mtime_ms] > rb_stat[:mtime_ms]
      elsif File.exist?(gmm_path) && File.exist?(rb_path)
        needs_generation = File.mtime(gmm_path).to_i > File.mtime(rb_path).to_i
      else
        needs_generation = true
      end
    rescue Exception => e
      puts "MapGenerator: Error checking file stats: #{e.message}"
      needs_generation = true
    end

    if needs_generation
      puts "MapGenerator: Generating #{rb_path} from #{gmm_path}..."
      generate(gmm_path, rb_path)
    end
  end

  def self.generate(gmm_path, rb_path)
    map = GmmParser.parse(gmm_path)
    unless map
      puts "MapGenerator: Failed to parse #{gmm_path}"
      return
    end

    grid_w = map[:width]
    grid_h = map[:height]
    lines = []
    
    (0...grid_h).each do |y|
      line = ""
      (0...grid_w).each do |x|
        index = y * (map[:width] + 1) + x
        tile = map[:floors][index]
        line += tile == 1 ? "." : "w"
      end
      lines << line
    end

    out_lines = []
    (0...grid_h).each do |y|
      line = ""
      (0...grid_w).each do |x|
        if lines[y][x] == "."
          line += "."
        else
          shape = WallShape.classify(
            t:  y > 0           && lines[y-1][x] == "w",
            b:  y < grid_h - 1  && lines[y+1][x] == "w",
            l:  x > 0           && lines[y][x-1] == "w",
            r:  x < grid_w - 1  && lines[y][x+1] == "w",
            tl: y > 0           && x > 0          && lines[y-1][x-1] == "w",
            tr: y > 0           && x < grid_w - 1 && lines[y-1][x+1] == "w",
            bl: y < grid_h - 1  && x > 0          && lines[y+1][x-1] == "w",
            br: y < grid_h - 1  && x < grid_w - 1 && lines[y+1][x+1] == "w"
          )
          line += shape.char
        end
      end
      out_lines << line
    end

    name = gmm_path.split("/").last.split(".").first.upcase

    out_str = "module MapLayouts\n"
    out_str += "  #{name}_LAYOUT = [\n"
    out_lines.each do |l|
      out_str += "    %w(#{l}),\n"
    end
    out_str += "  ]\n"
    out_str += "end\n"

    $gtk.write_file(rb_path, out_str)
  end
end
