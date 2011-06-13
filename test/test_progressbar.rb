require 'helper'


require 'stringio'
class TestProgressBar < Test::Unit::TestCase
  def test_progress_bar_start
    io = StringIO.new
    prg= ProgressBar.new
    prg.out = io
    prg.show_percent = true
    prg.size = 5
    prg.start("downloading")
    io.rewind
    assert io.read == "downloading\n_____"
  end
  def test_progress_bar_end
    io = StringIO.new
    prg= ProgressBar.new
    prg.out = io
    prg.size = 10
    prg.show_percent = true
    prg.end("done")
    io.rewind
    assert io.read =="\r          \r########## 100% done\n"
  end
  def test_progress_bar_progress_twice
    io = StringIO.new
    prg= ProgressBar.new
    prg.out = io
    prg.show_percent = true
    prg.size = 10
    prg.progress(40, "40/100")
    prg.progress(50, "50/100")
    io.rewind
    assert io.read == "\r          \r####______ 40% 40/100\r                      \r#####_____ 50% 50/100"
  end
  def test_progress_bar_progress_change_done_char
    io = StringIO.new
    prg= ProgressBar.new
    prg.out = io
    prg.bar_char_done = "="
    prg.show_percent = true
    prg.size = 10
    prg.progress(40, "40/100")
    prg.progress(50, "50/100")
    io.rewind
    assert io.read == "\r          \r====______ 40% 40/100\r                      \r=====_____ 50% 50/100"
  end
  def test_progress_bar_progress_change_undone_char
    io = StringIO.new
    prg= ProgressBar.new
    prg.out = io
    prg.bar_char_done = "="
    prg.bar_char_undone = "-"
    prg.show_percent = true
    prg.size = 10
    prg.progress(40, "40/100")
    prg.progress(50, "50/100")
    io.rewind
    assert io.read == "\r          \r====------ 40% 40/100\r                      \r=====----- 50% 50/100"
  end
  def test_progress_bar_progress_out_range
    begin
      io = StringIO.new
      prg= ProgressBar.new
      prg.out = io
      prg.progress(110, "110/100")
    rescue => e
      assert e.class == ArgumentError
    end
  end
  def test_progress_bar_100_percent
    io = StringIO.new
    prg= ProgressBar.new
    prg.out = io
    prg.bar_char_done = "="
    prg.bar_char_undone = "-"
    prg.show_percent = true
    prg.size = 5
    prg.progress(100, "100/100")
    io.rewind
    assert io.read == "\r     \r===== 100% 100/100"
  end
end

