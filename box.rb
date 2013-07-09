require 'sqlite3'
require 'pry'
require_relative 'manager'
require_relative 'compare'

puts `clear`
puts 'BOX'
puts `ruby -v`

print 'directory: '
directory = gets.chomp

print '(f)ingerprint, (c)compare or (a)rchive: '
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

if response == 'a'
end
