class Node
  attr_accessor :db, :files

  def initialize(db)
    @db = db
    @files = {}
    @db.execute 'update nodes set status_id = 0 where status_id in (0, 1);'
  end

  def cleanup
    @db.execute 'update nodes set status_id = 4 where status_id = 0;'
  end

  def dive(dir)
    Dir.chdir(dir)
    Dir.entries(Dir.pwd).each do |object|
      if is_valid_object?(object)
        object = sanitize_name(object)

        next if delete_dot_file(object)
        next if delete_empty_file(object)

        if safe_file?(object)
          hash = compute_hash(object)
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
    rows = find_record(object, hash)

    # new file
    if !rows.any?
      ancestor_id = nil
      status_id = 1
      @db.execute 'insert into nodes (file, directory, sha1, ancestor_id, status_id, created_at) values (?, ?, ?, ?, ?, ?);', object, Dir.pwd, hash, ancestor_id, status_id, Time.now.to_s
    end

    # unchanged file
    if rows.any? && rows[0][1] == object && rows[0][2] == Dir.pwd && rows[0][3] == hash
      @db.execute 'update nodes set status_id = 1 where id = ?', rows[0][0]
    end

    # moved file
    if rows.any? && (rows[0][1] != object || rows[0][2] != Dir.pwd) && rows[0][3] == hash
      @db.execute 'update nodes set status_id = 2 where id = ?', rows[0][0]
      ancestor_id = rows[0][0]
      status_id = 1
      @db.execute 'insert into nodes (file, directory, sha1, ancestor_id, status_id, created_at) values (?, ?, ?, ?, ?, ?);', object, Dir.pwd, hash, ancestor_id, status_id, Time.now.to_s
    end

    # changed file
    if rows.any? && rows[0][1] == object && rows[0][2] == Dir.pwd && rows[0][3] != hash
      @db.execute 'update nodes set status_id = 3 where id = ?', rows[0][0]
      ancestor_id = rows[0][0]
      status_id = 1
      @db.execute 'insert into nodes (file, directory, sha1, ancestor_id, status_id, created_at) values (?, ?, ?, ?, ?, ?);', object, Dir.pwd, hash, ancestor_id, status_id, Time.now.to_s
    end
  end

  def find_record(object, hash)
    @db.execute 'select * from nodes where (sha1 = ? or (file = ? and directory = ?)) and status_id in (0, 1);', hash, object, Dir.pwd
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
    ['.', '..', 'pandora.db'].include?(object)
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
    if @files[hash].nil?
      @files[hash] = true
    else
      puts "Deleting DUPLICATE #{Dir.pwd}/#{object}"
      `rm -rf #{object}`
    end
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
end
