class Compare
  attr_accessor :old_files, :new_files

  def initialize(directory, o_db, n_db)
    @old_files = {}
    @new_files = {}

    old_db = SQLite3::Database.new "#{directory}/database/#{o_db}"
    new_db = SQLite3::Database.new "#{directory}/database/#{n_db}"

    old_rows = old_db.execute 'select * from nodes;'
    new_rows = new_db.execute 'select * from nodes;'

    old_rows.each do |row|
      @old_files[row[3]] = "#{row[2]}/#{row[1]}"
    end

    new_rows.each do |row|
      @new_files[row[3]] = "#{row[2]}/#{row[1]}"
    end
  end

  def analyze
    display_new_files
    display_mov_files
    display_chg_files
    display_del_files
  end

  def display_new_files
    new_files.keys.each do |sha1|
      puts "NEW : #{new_files[sha1]}" if old_files[sha1].nil?
    end
  end

  def display_mov_files
    new_files.keys.each do |sha1|
      puts "MOV : #{new_files[sha1]}" if !old_files[sha1].nil? && (old_files[sha1] != new_files[sha1])
    end
  end

  def display_chg_files
    new_files.keys.each do |sha1|
      puts "CHG : #{new_files[sha1]}" if old_files[sha1].nil? && old_files.values.include?(new_files[sha1])
    end
  end

  def display_del_files
    old_files.keys.each do |sha1|
      puts "DEL : #{old_files[sha1]}" if new_files[sha1].nil? && !new_files.values.include?(old_files[sha1])
    end
  end
end
