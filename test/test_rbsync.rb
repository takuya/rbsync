require 'helper'

require 'tmpdir'
require 'find'
require 'pp'
class TestRbsync < Test::Unit::TestCase
  def test_sync_old_to_new
    Dir.mktmpdir('foo') do |dir|
      Dir.chdir dir do 
        Dir.mkdir("old")
        Dir.mkdir("new")
        open("./old/test.txt", "w+"){|f| 10.times{f.puts("test")}}
        rsync = RbSync.new
        rsync.sync("old","new")
        assert FileUtils.cmp("old/test.txt","new/test.txt")
      end
    end
  end
  def test_sync_old_to_new_and_overwrite
    Dir.mktmpdir('goo') do |dir|
      Dir.chdir dir do 
        Dir.mkdir("old")
        Dir.mkdir("new")
        open("./old/test.txt", "w+"){|f| 10.times{f.puts("test")}}
        open("./new/test.txt", "w+"){|f| 10.times{f.puts("tests")}}
        rsync = RbSync.new
        rsync.sync("old","new")
        assert FileUtils.cmp("old/test.txt","new/test.txt")
      end
    end
  end
  def test_sync_but_newdir_is_already_updated
    Dir.mktmpdir('goo') do |dir|
      Dir.chdir dir do 
        Dir.mkdir("old")
        Dir.mkdir("new")
        open("./old/test.txt", "w+"){|f| 10.times{f.puts("test")}}
        open("./new/test.txt", "w+"){|f| 10.times{f.puts("different")}}
        File::utime( Time.local(2038, 1, 1, 1, 1, 1), Time.local(2038, 1, 1, 1, 1, 1), "./new/test.txt")
        rsync = RbSync.new
        rsync.sync("old","new",{:update=>true})
        assert (FileUtils.cmp("old/test.txt","new/test.txt")  == false )
      end
    end
  end
  def test_sync_old_to_new_by_hash
    Dir.mktmpdir('foo') do |dir|
      Dir.chdir dir do 
        Dir.mkdir("old")
        Dir.mkdir("new")
        open("./old/test.txt", "w+"){|f| 10.times{f.puts("test")}}
        open("./new/test.txt", "w+"){|f| 10.times{f.puts("tests")}}
        rsync = RbSync.new
        rsync.sync("old","new",{:check_hash=>true})
        assert FileUtils.cmp("old/test.txt","new/test.txt")
      end
    end
  end
  def test_sync_old_to_new_by_hash_no_file
    Dir.mktmpdir('foo') do |dir|
      Dir.chdir dir do 
        Dir.mkdir("old")
        Dir.mkdir("new")
        open("./old/test.txt", "w+"){|f| 10.times{f.puts("test")}}
        open("./new/test.txt", "w+"){|f| 10.times{f.puts("different")}}
        File::utime( Time.local(2038, 1, 1, 1, 1, 1), Time.local(2038, 1, 1, 1, 1, 1), "./new/test.txt")
        rsync = RbSync.new
        rsync.sync("old","new",{:check_hash=>true,:update=>true})
        assert FileUtils.cmp("old/test.txt","new/test.txt") == false
      end
    end
  end
  def test_sync_old_to_new_by_hash_and_limit
    Dir.mktmpdir('foo') do |dir|
      Dir.chdir dir do 
        Dir.mkdir("old")
        Dir.mkdir("new")
        open("./old/test.txt", "w+"){|f| 1000.times{f.puts("test")}}
        open("./new/test.txt", "w+"){|f| 1000.times{f.puts("tests")}}
        rsync = RbSync.new
        rsync.sync("old","new",{:check_hash=>true,:hash_limit_size=>1024})
        assert FileUtils.cmp("old/test.txt","new/test.txt")
      end
    end
  end
  def test_sync_failed_hash_limit_size_is_too_small
    Dir.mktmpdir('foo') do |dir|
      Dir.chdir dir do 
        Dir.mkdir("old")
        Dir.mkdir("new")
        open("./old/test.txt", "w+"){|f| 3072.times{f.write("a")}}
        open("./new/test.txt", "w+"){|f| 2048.times{f.write("a")}}
        rsync = RbSync.new
        rsync.sync("old","new",{:check_hash=>true,:hash_limit_size=>1024})
        assert FileUtils.cmp("old/test.txt","new/test.txt") == false
      end
    end
  end
  def test_sync_with_exclude_pattern
    Dir.mktmpdir('foo') do |dir|
      Dir.chdir dir do 
        Dir.mkdir("old")
        Dir.mkdir("new")
        open("./old/test.txt", "w+"){|f| 10.times{f.puts("test")}}
        open("./old/test.rb", "w+"){|f| 10.times{f.puts("test")}}
        rsync = RbSync.new
        rsync.sync("old","new",{:excludes=>["*.txt","*.rb"]})
        assert (File.exists? "new/test.txt" ) == false
        assert (File.exists? "new/test.rb" ) == false
      end
    end
  end
  def test_sync_no_overwrite
    Dir.mktmpdir('goo') do |dir|
      Dir.chdir dir do 
        Dir.mkdir("old")
        Dir.mkdir("new")
        open("./old/test.txt", "w+"){|f| 10.times{f.puts("test")}}
        open("./new/test.txt", "w+"){|f| 10.times{f.puts("different")}}
        rsync = RbSync.new
        rsync.sync("old","new",{:overwrite=>false})
        assert FileUtils.cmp("old/test.txt","new/test.txt") == false
        rsync.sync("old","new",{:overwrite=>false,:check_hash=>true})
        assert FileUtils.cmp("old/test.txt","new/test.txt") == false
      end
    end
  end
  def test_sync_with_rename
    Dir.mktmpdir('goo') do |dir|
        Dir.chdir dir do 
          Dir.mkdir("old")
          Dir.mkdir("new")
          open("./old/test.txt", "w+"){|f| 10.times{f.puts("test")}}
          rsync = RbSync.new
          rsync.sync("old","new")
          assert FileUtils.cmp("old/test.txt","new/test.txt") == true
          open("./old/test.txt", "w+"){|f| 10.times{f.puts("changed")}}
          rsync.sync("old","new",{:rename => true})
          assert FileUtils.cmp("old/test.txt","new/test.txt") == false
          assert FileUtils.cmp("old/test.txt","new/test(1).txt") == true
          open("./old/test.txt", "w+"){|f| 10.times{f.puts("changed!!!")}}
          rsync.sync("old","new",{:rename => true})
          assert FileUtils.cmp("old/test.txt","new/test(2).txt") == true
        end
      end
    end
   def test_sync_with_backup
     Dir.mktmpdir('goo') do |dir|
      Dir.chdir dir do 
        Dir.mkdir("old")
        Dir.mkdir("new")
        # 同名のファイルを作って
        open("./old/test.txt", "w+"){|f| 10.times{f.puts("test")}}
        old_content =open("./old/test.txt", "r").read
        # ミラーして
        rsync = RbSync.new
        rsync.sync("old","new")
        assert FileUtils.cmp("old/test.txt","new/test.txt") == true
        open("./old/test.txt", "w+"){|f| 10.times{f.puts("changed")}}
        # バックアップ同期する
        rsync.sync("old","new",{:backup => true})
        assert FileUtils.cmp("old/test.txt","new/test.txt") == true
        # バックアップしたファイルがどうなっているか見る
        files = Dir.glob "./new/**/*"
        assert old_content == open((files - ["./new/test.txt"]).first).read
      end
    end
  end
  def test_sync_old_to_new_twice
    Dir.mktmpdir('foo') do |dir|
      Dir.chdir dir do 
        Dir.mkdir("old")
        Dir.mkdir("new")
        open("./old/test.txt", "w+"){|f| 10.times{f.puts("test")}}
        rsync = RbSync.new
        rsync.sync("old","new")
        rsync.sync("old","new")
        assert FileUtils.cmp("old/test.txt","new/test.txt")
        files = Dir.glob "./new/**/*"
        assert files.size == 1
      end
    end
  end
  def test_sync_old_to_new_sub_dir
    Dir.mktmpdir('foo') do |dir|
      Dir.chdir dir do 
        Dir.mkdir("old")
        Dir.mkdir("old/dir1")
        Dir.mkdir("new")
        open("./old/dir1/test.txt", "w+"){|f| 10.times{f.puts("test")}}
        rsync = RbSync.new
        rsync.sync("old","new")
        assert FileUtils.cmp("old/dir1/test.txt","new/dir1/test.txt")
        files = Dir.glob "./new/**/*"
        files = files.reject{|e| File.directory?(e) }
        assert files.size == 1
      end
    end
  end
  def test_sync_old_to_new_sub_dir2
    Dir.mktmpdir('foo') do |dir|
      Dir.chdir dir do 
        Dir.mkdir("old")
        Dir.mkdir("old/dir1")
        Dir.mkdir("new")
        open("./old/dir1/test.txt", "w+"){|f| 10.times{f.puts("test")}}
        open("./old/dir1/test2.txt", "w+"){|f| 10.times{f.puts("test")}}
        rsync = RbSync.new
        rsync.sync("old","new")
        assert FileUtils.cmp("old/dir1/test.txt","new/dir1/test.txt")
        files = Dir.glob "./new/**/*"
        files = files.reject{|e| File.directory?(e) }
        assert files.size == 2
      end
    end
  end
  def test_sync_preserve_time_stamp_1
    Dir.mktmpdir('goo') do |dir|
      Dir.chdir dir do 
        Dir.mkdir("old")
        Dir.mkdir("new")
        open("./old/test.txt", "w+"){|f| 10.times{f.puts("test")}}
        open("./new/test.txt", "w+"){|f| 10.times{f.puts("different")}}
        time1 = Time.local(2018, 1, 1, 1, 1, 1)
        time2 = Time.local(2008, 1, 1, 1, 1, 1)
        # //old/test.txt is more newer than ./new/test.txt
        File::utime( time1 , time1, "./old/test.txt")
        File::utime( time2 , time2, "./new/test.txt")
        rsync = RbSync.new
        rsync.sync("old","new",{:update=>true})
        assert File.atime("./new/test.txt") == time1
      end
    end
  end
  def test_sync_preserve_time_stamp_2
    Dir.mktmpdir('goo') do |dir|
      Dir.chdir dir do 
        Dir.mkdir("old")
        Dir.mkdir("new")
        open("./old/test.txt", "w+"){|f| 10.times{f.puts("test")}}
        time1 = Time.local(2008, 1, 1, 1, 1, 1)
        File::utime( time1 , time1, "./old/test.txt")
        rsync = RbSync.new
        rsync.sync("old","new",{:update=>true})
        # timestamp is preserved?
        assert File.mtime("./new/test.txt") == time1
        assert File.atime("./new/test.txt") == time1
      end
    end
  end

end
