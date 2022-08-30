require 'zip'

z = Zip::File.open('mitsu.zip')

# remove all json files, its confidential
to_rem = z.select do |e| e.name[-1] != '/' && File.extname(e.name) == '.json' end.map(&:name)
to_rem.each do |fn| z.remove(fn) end; 0

# remove all empty directories
loop do
  dirs = z.select do |e| e.name[-1] == '/' end.map(&:name)
  dir_contents = dirs.map do |d| [d, z.select { |e| e.name.start_with?(d) && e.name != d }.map(&:name)] end.to_h
  to_rem = dir_contents.select do |k,v| v.empty? end.keys
  break if to_rem.empty?
  to_rem.each do |fn| z.remove(fn) end; 0
end

z.commit