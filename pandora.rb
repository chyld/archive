#!/usr/bin/env ruby

require 'sqlite3'
require 'pry'
require_relative 'node'

puts `clear`
puts 'PANDORA'
puts `ruby -v`

print 'Directory to Backup: '
dir = gets.strip
db = SQLite3::Database.new "#{dir}/pandora.db"

# database:  pandora.db
# table:     nodes
# status_id: 0 - processing, 1 - normal, 2 - moved, 3 - changed, 4 - deleted
db.execute <<-SQL
  create table if not exists nodes(id integer primary key asc, file text, directory text, sha1 text, ancestor_id integer, status_id integer, created_at text);
SQL

root = Node.new(db)
root.dive(dir)
root.cleanup
