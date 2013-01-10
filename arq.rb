#!/usr/bin/env ruby

def read_directory(directory)
  Dir.chdir(directory)
  file_hash = manifest_init

  Dir.entries(Dir.pwd).each do |object|
    progress_display
    object = sanitize_name(object)
    next if delete_dot_file(object)
    next if delete_empty_file(object)
    reset_permissions(object)
    manifest_save(object, directory, file_hash)
    read_directory(object) if safe_directory?(object)
  end

  manifest_exit(file_hash)
  Dir.chdir('..')
end

def progress_display
  log(['+', '-'].sample, false)
end

def safe_directory?(object)
  File.directory?(object) && !reserved_name?(object)
end

def safe_file?(object)
  !File.directory?(object) && !reserved_name?(object)
end

def reserved_name?(object)
  ['.', '..', '.manifest'].include?(object)
end

def sanitize_name(oldname)
  newname = oldname.gsub(/[^0-9A-Za-z.\-]/, '-')
  newname.downcase!
  newname = newname.gsub(/^-/, 'x')
  File.rename(oldname, newname) if oldname != newname
  newname
end

def delete_dot_file(object)
  `rm -rf #{object}` if object.start_with?('.') && !reserved_name?(object)
end

def delete_empty_file(object)
  `rm -rf #{object}` if File.zero?(object)
end

def reset_permissions(object)
  `xattr -c #{object}`

  if safe_directory?(object)
    File.chmod(0755, object)
  elsif safe_file?(object)
    File.chmod(0644, object)
  end
end

def compute_hash(object)
  sha1_hash = `openssl dgst -sha1 #{object}`
  sha1_hash.strip!
  sha1_hash[(sha1_hash.length - 40)..(sha1_hash.length - 1)]
end

def encrypt(file, password, mutator, method, input, output)
  `openssl enc -#{method} -salt -pass pass:#{password}#{eval(mutator)} -in #{file}.#{input} -out #{file}.#{output}`
end

def manifest_init
  file_hash = {}
  return file_hash if !File.exist?('.manifest')
  IO.readlines('.manifest').map do |line|
    data = line.split(', ').map{|item| item.strip}
    file_hash[data[2]] = [data[0], data[1]]
  end
  File.delete('.manifest')
  file_hash
end

def manifest_exit(file_hash)
  manifest_log(nil, nil, nil, file_hash, nil)
end

def manifest_save(object, parent, file_hash)
  sha1_hash = File.directory?(object) ? '0' * 40 : compute_hash(object)
  file_type = File.directory?(object) ? 'c' : 'f'

  if object == '.'
    object = 'self'
    file_type = 's'
  end

  if object == '..'
    object = parent
    file_type = 'p'
  end

  manifest_log(object, parent, file_type, file_hash, sha1_hash)
  File.open('.manifest', 'a') {|f| f.write "#{sha1_hash}, #{file_type}, #{object}\n"}
end

def manifest_log(object, parent, file_type, file_hash, sha1_hash)
  return if ['s', 'p'].include?(file_type)

  if file_hash[object] && file_hash[object][0] == sha1_hash
    # unmodified file
  elsif file_hash[object] && file_hash[object][0] != sha1_hash
    log "mod : #{file_type} : #{parent}/#{object} #{file_hash[object][0]} -> #{sha1_hash}"
  elsif object
    log "new : #{file_type} : #{parent}/#{object}"
  else
    file_hash.each {|k,v| log "del : #{k}" if ['c', 'f'].include?(v[1])}
  end

  file_hash.delete(object)
end

def log(message, save = true)
  puts message
  File.open("/tmp/#{@time_stamp}.arq.log", 'a') {|f| f.write "#{message}\n"} if save
end

puts `clear`
puts `ruby -v`
puts '--- arq ---'

puts 'directory to backup?'
puts '--------------------'
root_dir = gets.strip.gsub('/', '')
puts 'describe this backup?'
puts '---------------------'
describe = gets.strip
puts 'password?'
puts '---------'
password = gets.strip
puts 'password mutator lambda?'
puts '------------------------'
puts 'variables: file, password, mutator, method, input, output'
puts "examples:  'test'*(input**output)"
mutator  = gets.strip
puts `openssl enc --help`
puts 'encryption engines, comma separated, no spaces?'
puts '-----------------------------------------------'
engines  = gets.strip.split(',')
puts 'verification only t or f?'
puts '-------------------------'
verify   = gets.strip == 't'

@time_stamp = Time.now.strftime('%Y%m%d%H%M%S')
read_directory(root_dir)
exit if verify
`tar -czvf #{@time_stamp}.0 #{root_dir}`
engines.each_with_index {|engine, index| puts engine; encrypt(@time_stamp, password, mutator, engine, index, index+1)}
tempname = "#{@time_stamp}.#{engines.count}"
sha1hash = compute_hash(tempname)
fullname = "#{@time_stamp}.#{sha1hash}.#{describe}"
`mkdir #{fullname}`
`split -b 300m #{tempname} #{fullname}/#{fullname}.chyld.p-`
(0..engines.count).each {|i| `rm #{@time_stamp}.#{i}`}

puts "goodbye"
