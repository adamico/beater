# app/gmm_parser.rb

class GmmParser
  def self.parse(file_path)
    data = $gtk.read_file(file_path)
    return nil unless data

    # 1. Read RIFF Header
    magic, _file_size, form_type = data.unpack("a4Va4")
    return nil unless magic == "RIFF" && form_type == "GRMM"

    map_data = { width: nil, height: nil, floors: nil }

    parse_chunks(data, 12, data.length, "", map_data)

    if map_data[:width] && map_data[:height] && map_data[:floors]
      map_data
    else
      nil
    end
  end

  def self.parse_chunks(data, start_offset, end_offset, current_list_type, map_data)
    offset = start_offset
    while offset < end_offset
      chunk_id, chunk_size = data.byteslice(offset, 8).unpack("a4V")
      offset += 8
      
      chunk_end = offset + chunk_size

      if chunk_id == "LIST"
        list_type = data.byteslice(offset, 4)
        parse_chunks(data, offset + 4, chunk_end, list_type, map_data)
      else
        if current_list_type == "lvl " && chunk_id == "prop"
          # This is the lvl prop chunk
          prop_offset = offset

          loc_len = data.byteslice(prop_offset, 2).unpack1("v")
          prop_offset += 2 + loc_len

          lvl_len = data.byteslice(prop_offset, 2).unpack1("v")
          prop_offset += 2 + lvl_len

          _elevation = data.byteslice(prop_offset, 2).unpack1("s<")
          prop_offset += 2

          map_data[:height] = data.byteslice(prop_offset, 2).unpack1("v")
          prop_offset += 2

          map_data[:width] = data.byteslice(prop_offset, 2).unpack1("v")
        elsif current_list_type == "lvl " && chunk_id == "cell"
          map_data[:floors] = parse_cell_layer(data.byteslice(offset, chunk_size))
        end
      end

      offset = chunk_end
      offset += 1 if chunk_size.odd? # padding
    end
  end

  def self.parse_cell_layer(cell_data)
    # We only care about Layer 0 (Floor)
    offset = 0
    compression_type = cell_data.byteslice(offset).unpack1("C")
    offset += 1

    layer_uncompressed = []

    if compression_type == 1
      comp_len = cell_data.byteslice(offset, 4).unpack1("V")
      offset += 4

      comp_data = cell_data.byteslice(offset, comp_len)
      
      idx = 0
      while idx < comp_data.length
        val = comp_data.byteslice(idx).unpack1("C")
        idx += 1
        if val < 0x80
          layer_uncompressed << val
        else
          repeat_count = (val & 0x7F) + 1
          data_byte = comp_data.byteslice(idx).unpack1("C")
          idx += 1
          repeat_count.times { layer_uncompressed << data_byte }
        end
      end
    elsif compression_type == 0
      # Not typically uncompressed in Gridmonger, but just in case
      # We don't know the exact length from this layer alone, so this is risky
      # It would just be the rest of the bytes or (cols+1)*(rows+1) bytes.
      # Gridmonger typically uses RLE.
    elsif compression_type == 2
      # Zeroes
      # layer_uncompressed would just be empty, filled with 0 later if needed
    end

    layer_uncompressed
  end
end
