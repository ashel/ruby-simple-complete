# -*- coding: utf-8 -*-

require "test/unit"

class SimpleCompleteTest < Test::Unit::TestCase
	def setup
		@oldpwd = Dir.pwd
		Dir.chdir(File.dirname(__FILE__) + "/data")
	end
	
	def teardown
		Dir.chdir(@oldpwd)
	end
	
	# 終了コードのテスト
	def test_exit_code
		# 補完候補が一つもない場合は失敗を返す
		assert( ! system("ruby ../../simple-complete.rb exit_code.rb 3:5"))
		# 補完候補が一つでもあれば成功を返す
		assert(system("ruby ../../simple-complete.rb exit_code.rb 4:3"))
	end
	
	# 何もrequireしない場合のテスト
	def test_no_require
		# 定数の補完を行う場合
		assert_equal("RUBY_VERSION\n", `ruby ../../simple-complete.rb no_require.rb 3:7`)
		# グローバル変数の補完を行う場合
		assert_equal("$stderr\n$stdin\n$stdout\n", `ruby ../../simple-complete.rb no_require.rb 4:5`)
		# 予約語が含まれているかのテスト
		assert_equal("while\n", `ruby ../../simple-complete.rb no_require.rb 5:6`)
		# 組み込み関数が含まれているかのテスト(カラムはバイト位置で指定することに注意)
		assert_match(/\bat_exit\b/, `ruby ../../simple-complete.rb no_require.rb 6:24`)
		# レシーバが定数であり、定数を参照している場合
		assert_match(/\bSEEK_END\b/, `ruby ../../simple-complete.rb no_require.rb 8:7`)
		# レシーバが定数であり、メソッドを呼び出している場合
		assert_match(/\bdelete\b/, `ruby ../../simple-complete.rb no_require.rb 9:8`)
		# レシーバが認識不可能な定数であり、定数を参照している場合
		assert_match(/\bArgumentError\b/, `ruby ../../simple-complete.rb no_require.rb 11:14`)
		# レシーバが何らかのオブジェクトであり、メソッドを呼び出している場合
		assert_match(/\bhour\b/, `ruby ../../simple-complete.rb no_require.rb 12:6`)
	end
end
