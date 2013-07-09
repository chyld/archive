class Manager
  attr_accessor :db, :files

  def initialize(directory, new_db)
    @files = {}
    @db = SQLite3::Database.new "#{directory}/database/#{new_db}.sqlite3"

    db.execute <<-SQL
      create table if not exists nodes(id integer primary key asc, file text, directory text, sha1 text);
    SQL
  end

  def dive(dir)
    Dir.chdir(dir)
    Dir.entries(Dir.pwd).each do |object|
      if is_valid_object?(object)
        object = sanitize_name(object)

        next if delete_dot_file(object)
        next if delete_empty_file(object)

        if safe_file?(object)
          hash = Manager.compute_hash(object)
          delete_duplicate_file(object, hash)
        end

        next if !File.exist?(object)

        reset_permissions(object)
        write_to_database(object, hash) if safe_file?(object)
        dive(object) if safe_directory?(object)
      end
    end
    Dir.chdir('..')
  end

  def write_to_database(object, hash)
    progress_display(object)
    @db.execute 'insert into nodes (file, directory, sha1) values (?, ?, ?);', object, Dir.pwd, hash
  end

  def progress_display(object)
    puts "#{Dir.pwd}/#{object}"
  end

  def is_valid_object?(object)
    safe_directory?(object) || safe_file?(object)
  end

  def safe_directory?(object)
    File.directory?(object) && !reserved_name?(object)
  end

  def safe_file?(object)
    !File.directory?(object) && !reserved_name?(object)
  end

  def reserved_name?(object)
    ['.', '..'].include?(object) || object.include?('.sqlite3')
  end

  def sanitize_name(oldname)
    newname = oldname.gsub(/[^0-9A-Za-z.\-]/, '-')
    newname.downcase!
    newname = newname.gsub(/^-/, 'x')
    File.rename(oldname, newname) if oldname != newname
    newname
  end

  def delete_dot_file(object)
    `rm -rf #{object}` if object.start_with?('.') && is_valid_object?(object)
  end

  def delete_empty_file(object)
    `rm -rf #{object}` if File.zero?(object)
  end

  def delete_duplicate_file(object, hash)
    @files[hash].nil? ? @files[hash] = true : `rm -rf #{object}`
  end

  def reset_permissions(object)
    `xattr -c #{object}`

    if safe_directory?(object)
      File.chmod(0755, object)
    elsif safe_file?(object)
      File.chmod(0644, object)
    end
  end

  def Manager.compute_hash(object)
    sha1_hash = `openssl dgst -sha1 #{object}`
    sha1_hash.strip!
    sha1_hash[(sha1_hash.length - 40)..(sha1_hash.length - 1)]
  end
end
