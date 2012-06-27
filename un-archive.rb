#!/usr/bin/env ruby

require 'fileutils'
include FileUtils

### ------------------------------------------------------------------------ ###

def crypto_aes(file, password)
  aes = "openssl enc -aes-256-cbc -salt -d -pass pass:#{password} -in #{file}.temp  -out #{file}.tar.gz"
  puts 'AES mode'
  `#{aes}`
end

def crypto_des(file, password)
  des = "openssl enc -des3        -salt -d -pass pass:#{password} -in #{file}.chyld -out #{file}.temp"
  puts 'DES mode'
  `#{des}`
end

def crypto(file, password)
  crypto_des(file, password)
  crypto_aes(file, password)
end

def concatenate_files(directory)
  first_file = Dir["#{directory}/**/*"].first
  pattern = /\/(.*?)-([0-9]{14})-([a-f0-9]{40})/m
  data = first_file.scan(pattern).flatten
  time_stamp = Time.now.strftime('%Y%m%d%H%M%S')
  output_file = "#{time_stamp}-#{data[0]}-#{data[1]}-#{data[2]}"
  output_hash = data[2]
  `cat #{directory}/*.chyld.* > #{output_file}.chyld`
  return output_file, output_hash
end

def get_file_checksum(file)
  hash = `openssl dgst -sha1 #{file}.chyld`
  pattern = /SHA1\(.*?.chyld\)= ([a-f0-9]{40})/m
  hash.scan(pattern).flatten.first
end

### ------------------------------------------------------------------------ ###

# it begins
puts `clear`
puts `ruby -v`
puts '--- Un-Archive Utility ---'
root_dir = ARGV[0]
password = ARGV[1]

# checking for archive directory and filehint and password
if root_dir.nil? || password.nil?
  puts "Missing _directory_ or _password_"
  exit
end

# strip off trailing slash
root_dir = root_dir.gsub(/\//, '')

# concatenate all file parts into whole
file, expected_hash = concatenate_files(root_dir)

# check the file integrity
actual_hash = get_file_checksum(file)
puts "Checksum : #{expected_hash} -> #{actual_hash}"
if expected_hash != actual_hash
  puts "File integrity check failed"
  exit
end

# decrypt the file
crypto(file, password)

# uncompress and untar
`mkdir #{file}`
`tar -xzvf #{file}.tar.gz -C #{file}`

# remove temporary files
`rm #{file}.*`

# done
puts "Success!"

