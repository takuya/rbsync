# encoding: utf-8


require 'fileutils'

# Synchronize files src to dest . 
# this class can sync files and recuresively
# options are
# +sync update file only
# +no overwrite when dist files are newer than src
# +sync by file digest hash , not useing filename
#
# == usage
# === mirror files
# 同期元と同期先を同じにする
#           require 'rbsync'
#           rsync =RbSync.new
#           rsync.sync( "src", "dest" )
# === mirror updated only files
# 同期先に、同期元と同名のファイルがあったら、更新日時を調べる。新しいモノだけをコピーする．
#           require 'rbsync'
#           rsync =RbSync.new
#           rsync.sync( "src", "dest",{:update=>true} )
# === using exclude pattern
# 同期先と同期元を同じにする，但し、*.rb / *.log の拡張子は除外する．
#           require 'rbsync'
#           rsync =RbSync.new
#           rsync.sync( "src", "dest",{:excludes=>["*.log","*.bak"]} )
# == sync by another name  if file name confilicts
# 名前が衝突した場合で、ファイルを書換える時は，転送元のファイルを別名で転送する
# windows のファイルコピーっぽい動作
# send src file with anothername.
# before sync
# |src  | test.txt | 2011-06-14
# |dest | test.txt | 2011-06-12
# after sync
# |src  | test.txt    | 2011-06-14
# |dest | test(1).txt | 2011-06-14 # same to src
# |dest | test.txt    | 2011-06-12
# == sync with backup 
# 名前が衝突した場合で、ファイルを書換える場合転送先のファイルを別名で保存してから転送する
# before sync
# |src  | test.txt | 2011-06-14
# |dest | test.txt | 2011-06-12
# after sync
# |src  | test.txt                   | 2011-06-14
# |dest | test.txt                   | 2011-06-14 # same to src
# |dest | test_20110614022255.txt    | 2011-06-12 # moved
#
#
# ==special usage , sync by file cotetets 
# if directory has a same file with different file name. insted of filename , sync file by file hash
# when files are theses,
#  |src| test.txt | "47bce5c74f589f4867dbd57e9ca9f808" |
#  |dst| test.bak | "47bce5c74f589f4867dbd57e9ca9f808" |
# :check_hash results no effect.
# ディレクトリ内のファイル名をうっかり変えてしまったときに使う．ファイル名でなく、ファイルの中身を比較して同期する．
#  |src| test.txt | "47bce5c74f589f4867dbd57e9ca9f808" |
#  |dst| test.bak | "47bce5c74f589f4867dbd57e9ca9f808" |
# の場合何もおきません
#           require 'rbsync'
#           rsync =RbSync.new
#           rsync.sync( "src", "dest",{:check_hash=>true} )
# === directory has very large file ,such as mpeg video
# using with :check_hash=>true
# checking only head of 1024*1024 bytes to distinguish src / dest files.this is for speed up.
# FileUtils::cmp is reading whole file. large file will take time.With :hash_limit_size Rbsync read only head of files for comparing.
# 巨大なファイルだと，全部読み込むのに時間が掛かるので、先頭1024*1024 バイトを比較してOKとする.写真とかはコレで十分
# ファイル名を書換えてしまってコンテンツ内容の比較だけで使う。
# :check_hash=>true とペアで使います
#           require 'rbsync'
#           rsync =RbSync.new
#           rsync.sync( "src", "dest",{:check_hash=>true,:hash_limit_size=1024*1024} )
# 
# === sync both updated files
# To sync both, call sync methods twice 
# 双方向に同期させたい場合は２回起動する．
#           require 'rbsync'
#           rsync =RbSync.new
#           rsync.updated_file_only = true
#           rsync.sync( "src", "dest" )
#           rsync.sync( "dest", "src" )# swap src to dest , dest to src
class RbSync
  attr_accessor :conf
  def initialize()
    @conf ={}
    @conf[:update] = false
    @conf[:excludes] = []
    @conf[:preserve] = true
  end
  # collect file paths. paths are relatetive path.
  def find_as_relative(dir_name,excludes=[])
    files =[]
    excludes = [] unless excludes
    Dir.chdir(dir_name){ 
      files = Dir.glob "./**/*", File::FNM_DOTMATCH
      exclude_files =[]
      exclude_files = excludes.map{|g| Dir.glob "./**/#{g}",File::FNM_DOTMATCH } 
      #files.each{|e|pp [e, File.directory?(e)]  }
      files = files.reject{|e| File.directory?(e)  }
      files = files - exclude_files.flatten
    }
    files = files.reject{|e| [".",".."].any?{|s| s== File::basename(e)  }}
  end
  # compare two directory by name and FileUtis,cmp
  def find_files(src,dest,options)
    src_files  = self.find_as_relative(  src, options[:excludes] )
    dest_files = self.find_as_relative( dest, options[:excludes] )

    # output target files
    puts "　　元フォルダ:"  +  src_files.size.to_s + "件" if self.debug?
    puts "同期先フォルダ:"  + dest_files.size.to_s + "件" if self.debug?
    #pp src_files if self.debug?
    sleep 1 if self.debug?

    #両方にあるファイル名で中身が違うもので src の方が古いもの
    same_name_files = (dest_files & src_files)
    same_name_files.reject!{|e|
        #ファイルが同じモノは省く
        FileUtils.cmp( File.expand_path(e,src) , File.expand_path(e,dest) ) 
    }
    if options[:update] then
      same_name_files= same_name_files.select{|e|
          (File.mtime(File.expand_path(e,src)) > File.mtime( File.expand_path(e,dest)))
      }
    end
    if options[:overwrite] == false then
      same_name_files= same_name_files.reject{|e|
          (File.exists?(File.expand_path(e,src)) && File.exists?( File.expand_path(e,dest)))
      }
    end
    files_not_in_dest = (src_files - dest_files)
    #files
    files =[]
    files = (files_not_in_dest + same_name_files ).flatten
  end
  def sync_by_hash(src,dest,options={})
    src_files   = collet_hash(find_as_relative(src, options[:excludes]), src, options)
    dest_files  = collet_hash(find_as_relative(dest,options[:excludes]),dest, options)
    target  = src_files.keys - dest_files.keys
    target = target.reject{|key|
      e = src_files[key].first
      options[:update] && 
      File.exists?( File.expand_path(e,dest)) &&
      (File.mtime(File.expand_path(e,src)) < File.mtime( File.expand_path(e,dest)))
    }
    if options[:overwrite] == false then
      target = target .reject{|key|
          e = src_files[key].first
          (File.exists?(File.expand_path(e,src)) && File.exists?( File.expand_path(e,dest)))
      }
    end
    puts "同期対象ファイル" if self.debug?
    puts target.each{|key|puts src_files[key].first} if self.debug?
    puts "同期対象はありません" if self.debug? and target.size==0

    files= target.map{|key|
        e = src_files[key].first
        [File.expand_path(e,src) , File.expand_path(e,dest)]
    }
    self.copy_r(files)

    ret = files.map{|e|
      FileTest.exist?(e[1])
    }
    puts "同期が終りました"     if ret.select{|e|!e}.size == 0 && self.debug?
    puts "同期に失敗したみたい" if ret.select{|e|!e}.size != 0 && self.debug?
  end
  def collet_hash(file_names,basedir,options={})
    #prepare
    require 'thread'
    threads =[]
    output = Hash.new{|s,key| s[key]=[] }
    q      = Queue.new
    limitsize = options[:hash_limit_size]
    # compute digests
    file_names.each{|e| q.push e }
    5.times{
      threads.push(
        Thread.start{
          while(!q.empty?)
            name = q.pop
            hash = compute_digest_file(File.expand_path(name,basedir),limitsize)
            output[hash].push name
          end
        }
      )
    }
    threads.each{|t|t.join}
    return output
  end
  # compute digest md5 
  # ==limitsize
  #   If file size is very large,
  #   and a few bytes at head of file is enough to compare.
  #   for speed-up, Set limit size to enable to avoid reading a whole of file.
  #   もしファイルがとても巨大で、かつ、先頭の数キロバイトが比較に十分であれば、limitsize 以降をスキップする
  def compute_digest_file(filename, limitsize=nil)
      require 'digest/md5'
      s = %{
      class Digest::Base
        def self.open(path,limitsize=nil)
          obj = new
          File.open(path, 'rb') do |f|
            buf = ""
            while f.read(256, buf)
              obj << buf
              break if f.pos > (limitsize or f.pos+1)
            end
          end
          return obj
        end
      end
      }
      eval s
      Digest::MD5.open(filename,limitsize).hexdigest
  end
  
  # called from sync
  def sync_normally(src,dest,options={})
    files = self.find_files(src,dest,options)
    puts "同期対象のファイルはありません" if self.debug? && files.size==0
    return true if files.size == 0
    puts "次のファイルを同期します" if self.debug?
    pp files                        if self.debug?
    
    #srcファイルをdestに上書き
    #todo options を取り出す
    self.copy_r(files.map{|e|[File.expand_path(e,src) , File.expand_path(e,dest)]})
    
    #checking sync result
    files = self.find_files(src,dest,options)

    puts "同期が終りました"       if files.size == 0 && self.debug?
    puts "同期に失敗がありました" if files.size != 0 && self.debug?
    pp files                      if files.size != 0 && self.debug?
    return files.size == 0
  end
  # 同期先に同名ファイルがあったらファイルを別名にバックアップしてから転送します
  def sync_with_backup(src,dest,options)
    # 上書き付加の場合
    # 
    #ファイル一覧を取得する
    files = find_as_relative(src,options[:excludes])
    #中身が同じモノを排除
    files = files.reject{|e|
      FileUtils.cmp(File.expand_path(e,src) , File.expand_path(e,dest))
    }
    #更新日が当たらしいモノを排除
    if options[:update] then
      #更新日が当たらしいモノを排除
      files = files.reject{|e|
        File.mtime(File.expand_path(e,src)) < File.mtime(File.expand_path(e,dest))
      }
    end
    #別名をつける
    files = files.map{|e|
      extname = File.extname(e)
      basename = File.basename(e).gsub(extname,"")
        # 同名のファイルがあった場合
        # ファイルをリネームする
        if File.exists?(File.expand_path(e,dest)) then
            candidate = File.expand_path("#{basename}_#{Time.now.strftime('%Y%m%d%H%M%S')}#{extname}",dest)
            File.rename( File.expand_path(e,dest),candidate )
        end
      [File.expand_path(e,src) , File.expand_path(e,dest)]
    }
    #コピーする
    self.copy_r(files)
  end
  # 別名で名前をつけて転送する
  def sync_by_anothername(src,dest,options)
    # 上書き付加の場合
    # 
    #ファイル一覧を取得する
    files = find_as_relative(src,options[:excludes])
    #中身が同じモノを排除
    files = files.reject{|e|
      FileUtils.cmp(File.expand_path(e,src) , File.expand_path(e,dest))
    }
    if options[:update] then
      #更新日が当たらしいモノを排除
      files = files.reject{|e|
        File.mtime(File.expand_path(e,src)) < File.mtime(File.expand_path(e,dest))
      }
    end
    #別名をつける
    files = files.map{|e|
      extname = File.extname(e)
      basename = File.basename(e).gsub(extname,"")
      candidate = ""
      100.times{|i|
        candidate = File.expand_path("#{basename}(#{i+1})#{extname}",dest)
        break unless File.exists?(File.expand_path(candidate,dest))
        raise "upto #{i} files are already exists ." if  i >=1000
        next FileUtils.cmp(File.expand_path(e,src) , File.expand_path(candidate,dest))
      }
      [File.expand_path(e,src) , File.expand_path(candidate,dest)]
    }
    #コピーする
    self.copy_r(files)
  end
  def copy_r(files)
    if(@conf[:progress])
      puts ("copy #{files.size} files")
      $stdout.flush
    end
    files.each_with_index{|e,i|
      #show
      if(@conf[:progress])
        puts ("start #{i+1}/#{files.size}")
        $stdout.flush
      end
      #main
      copy_thread = Thread.start{
        FileUtils.mkdir_p File.dirname(e[1]) unless File.exists?(File.dirname(e[1]))
        FileUtils.copy( e[0] , e[1] ,{:preserve=>self.preserve?,:verbose=>self.verbose? } )
      }
      #progress of each file
      progress_thread = nil
      if(@conf[:progress])
        progress_thread = Thread.start{
          bar = ProgressBar.new
          bar.size = 30
          src_size = File.size(e[0])
          dst_size = -1
          bar.start("copying #{e[0]} to #{e[1]}")
          while(src_size!=dst_size)
            src_size = File.size(e[0]).to_f
            dst_size = File.size(e[1]).to_f
            bar.progress(((dst_size/src_size)*100).to_int)
            sleep 0.2
          end
          bar.end("done")
        }
      end
      copy_thread.join
      progress_thread.join if progress_thread 
    }
  end
  def sync(src,dest,options={})
    options[:excludes]        = self.excludes.push(options[:excludes]).flatten.uniq if options[:excludes]
    options[:update]          = @conf[:update]                                if options[:update] == nil
    options[:check_hash]      = options[:check_hash] and @conf[:check_hash]
    options[:hash_limit_size] = @conf[:hash_limit_size]                       if options[:hash_limit_size] == nil
    options[:overwrite]       = @conf[:overwrite]                             if options[:overwrite] == nil
    options[:overwrite]       = false                                         if options[:no_overwrite]
    if options[:rename]
      return self.sync_by_anothername(src,dest,options)
    elsif options[:backup]
      return self.sync_with_backup(src,dest,options)
    elsif options[:check_hash]
      return self.sync_by_hash(src,dest,options)
    else
      return self.sync_normally(src,dest,options)
    end
  end
  
  #for setting

  def debug_mode?
    self.conf[:debug] ==true
  end
  def verbose?
    self.conf[:verbose] == true
  end
  def hash_limit_size
    @conf[:hash_limit_size]
  end

  # flag true or false
  def debug_mode=(flag)
    self.conf[:debug] = flag
  end
  # flag true or false
  def verbose=(flag)
    self.conf[:verbose] = flag
    $stdout.sync = flag
  end
  #
  # flag true or false
  def updated_file_only=(flag)
    @conf[:update] = flag
  end
  #
  # flag true or false
  def check_hash=(flag)
    @conf[:use_md5_digest] = flag
  end
  def hash_limit_size=(int_byte_size)
    @conf[:hash_limit_size] = int_byte_size
  end
  
  def excludes=(glob_pattern)
    @conf[:excludes].push glob_pattern
  end
  def excludes
    @conf[:excludes]
  end
  def preserve=(flag)
    @conf[:preserve] = false
  end
  def preserve?
    @conf[:preserve]
  end
  def overwrite=(flag)
    @conf[:overwrite] = flag
  end
  def overwrite?
    @conf[:overwrite]
  end

  #aliases

  alias debug? debug_mode?
  alias debug= debug_mode=
  alias update= updated_file_only=
  alias newer=   updated_file_only=
end

# ==プログレスバーを表示する．
#      prg= ProgressBar.new
#      prg.show_percent = true
#      prg.size = 60
#      prg.start("downloading\n")
#      100.times{|i|
#        prg.progress(i, "#{i}/100")
#        sleep 0.015
#      }
#      prg.end("done")
class ProgressBar
  attr_accessor :size, :out, :bar_char_undone, :bar_char_done, :show_percent
  def initialize()
    @out = $stdout
    @size = 10
    @bar_char_undone = "_"
    @bar_char_done   = "#"
    @show_percent    = true
    @printend_max_size = 0
  end
  def start(message="")
    out.puts message
    out.print bar_char_undone * size 
    out.flush
  end
  def end(message="")
    progress(100)
    out.print " " + message
    out.puts ""
    out.flush
  end
  def clear()
    out.print "\r"
    line_size = [@printend_max_size, @size].max
    out.print " " * line_size
    out.flush
  end
  def progress(percent,message=nil)
    clear()
    str =""
    str <<  "\r"
    str <<  bar_char_done   * ((percent.to_f/100.to_f)*size).to_i
    str <<  bar_char_undone * (size - ((percent.to_f/100.to_f)*size).to_i)
    str <<  " " + percent.to_s + "%" if show_percent
    str <<  " " + message  if message
    @printend_max_size = str.size if str.size > @printend_max_size
    out.print str
    out.flush
  end
end



if __FILE__ == $0
require 'tmpdir'
require 'find'
require 'pp'
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
        p File.mtime("./new/test.txt") == time1
        p File.atime("./new/test.txt") == time1
      end
    end
  puts :END
end
