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
end
