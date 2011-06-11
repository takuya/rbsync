#rbsyncの改良版。
# ファイル名でなくハッシュ値を計算してファイルを同期する。
#ファイルの同期

require 'fileutils'
$KCODE='u'

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
# ==special usage , sync by file cotetets 
# if directory has a same file with different file name. insted of filename , sync file by file hash
# ディレクトリ内のファイル名をうっかり変えてしまったときに使う．ファイル名でなく、ファイルの中身を比較して同期する．
#           require 'rbsync'
#           rsync =RbSync.new
#           rsync.sync( "src", "dest",{:check_hash=>true} )
# === directory has very large file ,such as mpeg video
# checking only head of 1024*1024 bytes to distinguish src / dest files for speed up.
# FileUtils::cmp is reading whole file. This will be so slow for large file
# 巨大なファイルだと，全部読み込むのに時間が掛かるので、先頭1024*1024 バイトを比較してOKとする
#           require 'rbsync'
#           rsync =RbSync.new
#           rsync.sync( "src", "dest",{:check_hash=>true,:hash_limit_size=1024*1024} )
# 
# === sync both updated files
# 双方向に同期させたい場合は２回起動する．
#           require 'rbsync'
#           rsync =RbSync.new
#           rsync.update = true
#           rsync.sync( "src", "dest" )
#           rsync.sync( "dest", "src" )
class RbSync
  attr_accessor :conf
  def initialize()
    @conf ={}
    @conf[:update] = false
    @conf[:excludes] = []
  end
  # collect file paths. paths are relatetive path.
  def find_as_relative(dir_name,excludes=[])
    files =[]
    excludes = [] unless excludes
    Dir.chdir(dir_name){ 
      files = Dir.glob "./**/*", File::FNM_DOTMATCH
      exclude_files =[]
      exclude_files = excludes.map{|g| Dir.glob "./**/#{g}",File::FNM_DOTMATCH } 
      files = files - exclude_files.flatten
    }
    files.reject{|e| [".",".."].any?{|s| s== File::basename(e)  }}
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
    files_not_in_dest = (src_files - dest_files)
    #files
    files =[]
    files = (files_not_in_dest + same_name_files ).flatten
  end
  def sync_by_hash(src,dest,options={})
    src_files   = collet_hash(find_as_relative(src, options), src, options)
    dest_files  = collet_hash(find_as_relative(dest,options),dest, options)
    target  = src_files.keys - dest_files.keys
    target = target.reject{|key|
      e = src_files[key].first
      options[:update] && 
      File.exists?( File.expand_path(e,dest)) &&
      (File.mtime(File.expand_path(e,src)) < File.mtime( File.expand_path(e,dest)))
    }
    puts "同期対象ファイル" if self.debug?
    puts target.each{|key|puts src_files[key].first} if self.debug?
    puts "同期対象はありません" if self.debug? and target.size==0
    ret = target.map{|key|
        e = src_files[key].first
        FileUtils.copy( File.expand_path(e,src) , File.expand_path(e,dest),
                        {:preserve=>self.preserve?,:verbose=>self.verbose? }) 
        FileTest.exist?(File.expand_path(e,dest))
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
  #   If file size is very large.
  #   And  a few byte head of file  is enough to compare.
  #   for speedup, setting limit size enable to skipp reading file.
  #   もしファイルがとても巨大で、かつ、先頭の数キロバイトで十分であれば、limitsize 以降をスキップする
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
  
  # ロジックが長すぎるので短くするか別に分ける．
  # ロジックのパターン毎に共通化する
  # ・ディレクトリ内のファイル一覧を作る
  # ・ファイル一覧を比較する
  # ・同期するファイル一覧を作って転送する
  def sync_nornally(src,dest,options={})
    files = self.find_files(src,dest,options)
    puts "同期対象のファイルはありません" if self.debug? && files.size==0
    return true if files.size == 0
    puts "次のファイルを同期します" if self.debug?
    pp files                        if self.debug?
    
    #srcファイルをdestに上書き
    #todo options を取り出す
    files.each{|e|
      FileUtils.copy( File.expand_path(e,src) , File.expand_path(e,dest),
      {:preserve=>self.preserve?,:verbose=>self.verbose? } )
    }
    files =[]
    
    #checking sync result
    files = self.find_files(src,dest,options)

    puts "同期が終りました"       if files.size == 0 && self.debug?
    puts "同期に失敗がありました" if files.size != 0 && self.debug?
    pp files                      if files.size != 0 && self.debug?
    return files.size == 0
  end
  def sync(src,dest,options={})
    options[:excludes] = (self.excludes + [options[:excludes]]).flatten.uniq if options[:excludes]
    options[:update]   = @conf[:update] if options[:update] == nil
    options[:check_hash] = options[:check_hash] and @conf[:check_hash]
    options[:hash_limit_size] = @conf[:hash_limit_size] if options[:hash_limit_size] == nil
    if options[:check_hash]
          return self.sync_by_hash(src,dest,options)
    else
          return self.sync_nornally(src,dest,options)
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

  #aliases

  alias debug? debug_mode?
  alias debug= debug_mode=
  alias update= updated_file_only=
  alias newer=   updated_file_only=
end


