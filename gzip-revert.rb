require_relative 'zlib-ext'
Dir.chdir(__dir__) do
  Dir.glob("**/*.m4a") do |fn|
    $stderr.puts fn
    ctx = File.binread(fn)
    next unless ctx.slice(0, 3) == "\x1f\x8b\x08".b
    File.binwrite(fn, Zlib.gunzip_hard(ctx))
  end
end