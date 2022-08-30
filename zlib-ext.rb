require 'stringio'
require 'zlib'

module ZlibExtension
  def gunzip_hard(str)
    s = StringIO.new
    s.write str.b
    s.rewind
    
    so = StringIO.new
    
    g = Zlib::GzipReader.new(s, encoding: Encoding::ASCII_8BIT)
    bs = [16, Math.log2(str.b.size).to_i].min
    begin
      so.write g.read(1 << bs)
    rescue Zlib::GzipFile::Error
      bs -= 1
      break if bs < 0
    end while true
    g&.close
    so.rewind
    so.read
  end
end

Zlib.extend ZlibExtension