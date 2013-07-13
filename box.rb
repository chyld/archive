require 'sqlite3'
require 'pry'
require_relative 'manager'
require_relative 'compare'

puts `clear`
puts 'BOX'
puts `ruby -v`

print 'directory: '
directory = gets.chomp

print '(f)ingerprint, (c)compare, (s)ha1 or (a)rchive: '
response = gets.chomp

if response == 'f'
  db = Time.now.strftime("%Y-%m-%d.%H-%M-%S")
  manager = Manager.new(directory, db)
  manager.dive(directory)
end

if response == 'c'
  print 'old db name: '
  old_db = gets.chomp

  print 'new db name: '
  new_db = gets.chomp

  compare = Compare.new(directory, old_db, new_db)
  compare.analyze
end

if response == 's'
  print 'filename: '
  filename = gets.chomp
  hash = Manager.compute_hash(filename)
  puts "#{filename} -> #{hash}"
end

if response == 'a'
  print 'password: '
  password = gets.chomp
  time_stamp = Time.now.strftime("%Y%m%d")

  tar = "tar -czvf #{time_stamp}.tar.gz #{directory}"
  puts tar
  `#{tar}`

  aes = "openssl enc -aes-256-cbc -salt -pass pass:'#{password}' -in #{time_stamp}.tar.gz -out #{time_stamp}.chyld"
  puts aes
  `#{aes}`

  hash = Manager.compute_hash("#{time_stamp}.chyld")
  cmd = "mv #{time_stamp}.chyld #{time_stamp}-#{hash}.chyld"
  puts cmd
  `#{cmd}`

  cmd = "rm #{time_stamp}.tar.gz"
  puts cmd
  `#{cmd}`
end
