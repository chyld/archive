#!/usr/bin/env ruby

require 'fileutils'
include FileUtils

### ------------------------------------------------------------------------ ###

def compute_sha1_hashes(directory, hashes)
  Dir[directory].each do |file|
    if !File.directory?(file)
      hashes << compute_sha1_hash(file)
    end
  end
end

def compute_sha1_hash(file)
  hash = `openssl dgst -sha1 #{file}`
  hash.strip!
  hash = hash[(hash.length - 40)..(hash.length - 1)]
  exit if hash.length != 40
  puts "#{hash} : #{hash.length} : #{file}"
  hash
end

def crypto_aes(file, password, encrypt)
  aes = "openssl enc -aes-256-cbc -salt #{'-d' if !encrypt} -pass pass:#{password} -in #{file}.#{encrypt ? 'tar.gz' : 'temp'} -out #{file}.#{encrypt ? 'temp' : 'tar.gz'}"
  puts aes
  `#{aes}`
end

def crypto_des(file, password, encrypt)
  des = "openssl enc -des3 -salt #{'-d' if !encrypt} -pass pass:#{password} -in #{file}.#{encrypt ? 'temp' : 'chyld'} -out #{file}.#{encrypt ? 'chyld' : 'temp'}"
  puts des
  `#{des}`
end

def crypto(file, password, encrypt)
  if encrypt
    crypto_aes(file, password, encrypt)
    crypto_des(file, password, encrypt)
  else
    crypto_des(file, password, encrypt)
    crypto_aes(file, password, encrypt)
  end
end

def copy_to_service(mode, service, output_file, filehint)
  archive_dir = "~/#{service}/archive"
  puts "creating archive directory : #{archive_dir}"
  `mkdir #{archive_dir}`

  file_dir = "#{archive_dir}/#{filehint}"
  puts "creating file directory : #{file_dir}"
  `mkdir #{file_dir}`

  output_dir = "#{file_dir}/#{output_file}"
  puts "creating output directory : #{output_dir}"
  `mkdir #{output_dir}`

  puts "#{mode} #{output_file}.chyld.p-* to #{output_dir}"
  `#{mode} #{output_file}.chyld.p-* #{output_dir}`
end

### ------------------------------------------------------------------------ ###

puts `clear`
puts `ruby -v`
puts '--- Archive Utility ---'
root_dir = ARGV[0]
filehint = ARGV[1]
password = ARGV[2]

# checking for archive directory and filehint and password
exit if root_dir.nil? || filehint.nil? || password.nil?

# strip off trailing slash
root_dir = root_dir.gsub(/\//, '')

# compute sha1 hashes for each file
before = []
compute_sha1_hashes("#{root_dir}/**/*", before)

# tar and compress files
time_stamp = Time.now.strftime('%Y%m%d%H%M%S')
`tar -czvf #{time_stamp}.tar.gz #{root_dir}`

# encrypt the files
crypto(time_stamp, password, true)

# get sha1 hash from encrypted file
encrypted_hash = compute_sha1_hash("#{time_stamp}.chyld")

# rename file using sha1 hash and date
output_file = "#{filehint}-#{time_stamp}-#{encrypted_hash}"
`mv #{time_stamp}.chyld #{output_file}.chyld`

# remove the temporary files
`rm #{time_stamp}.tar.gz #{time_stamp}.temp`

# decrypt the files
crypto(output_file, password, false)

# uncompress and untar
`mkdir #{output_file}`
`tar -xzvf #{output_file}.tar.gz -C #{output_file}`

# compute sha1 hashes for each file
after = []
compute_sha1_hashes("#{output_file}/#{root_dir}/**/*", after)

# compare number of files in each
puts "pre #{before.length} :> pst #{after.length}"
exit if before.length != after.length

# compare the hashes and exit if there is a difference
before.each_with_index do |item, index|
  puts "#{before[index]} :> #{after[index]}"
  exit if before[index] != after[index]
end

# split output file into smaller chunks
puts "splitting files"
`split -b 300m #{output_file}.chyld "#{output_file}.chyld.p-"`

# remove temporary files
`rm #{output_file}.tar.gz #{output_file}.temp #{output_file}.chyld`
`rm -rf #{output_file}`

# upload encrypted file to the cloud
copy_to_service("cp", "Dropbox", output_file, filehint)
copy_to_service("cp", "Skydrive", output_file, filehint)
copy_to_service("mv", "Google\\ Drive", output_file, filehint)

# done
puts "success!"

