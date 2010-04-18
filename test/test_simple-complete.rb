# -*- coding: utf-8 -*-

require "test/unit"

class SimpleCompleteTest < Test::Unit::TestCase
	def setup
		Dir.chdir("data")
	end
	
	def test_exit_code
		# 補完候補が一つもない場合は失敗を返す
		assert( ! system("ruby ../../simple-complete.rb exit_code.rb 2:5") )
		# 補完候補が一つでもあれば成功を返す
		assert( system("ruby ../../simple-complete.rb exit_code.rb 3:3") )
	end
end
