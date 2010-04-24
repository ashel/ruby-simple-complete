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
		assert_match(/(^|\n)at_exit\n/, `ruby ../../simple-complete.rb no_require.rb 6:24`)
		# ヒント文字列が何もない場合、組み込み関数、予約語、グローバル変数が含まれているかのテスト
		assert_match(/(^|\n)$stderr\n|(^|\n)while\n|(^|\n)at_exit\n/, `ruby ../../simple-complete.rb no_require.rb 7:1`)
		# レシーバが定数であり、定数を参照している場合
		assert_match(/(^|\n)SEEK_END\n/, `ruby ../../simple-complete.rb no_require.rb 8:7`)
		# レシーバが定数であり、メソッドを呼び出している場合
		assert_match(/(^|\n)delete\n/, `ruby ../../simple-complete.rb no_require.rb 9:8`)
		# レシーバが認識不可能な定数であり、定数を参照している場合
		assert_match(/(^|\n)ArgumentError\n/, `ruby ../../simple-complete.rb no_require.rb 11:14`)
		# レシーバが何らかのオブジェクトであり、メソッドを呼び出している場合
		assert_match(/(^|\n)hour\n/, `ruby ../../simple-complete.rb no_require.rb 12:6`)
		# レシーバが何らかのオブジェクトであり、ヒント文字列がなく、かつメソッドを呼び出している場合に演算子が含まれないかどうか
		assert(/(^|\n)<=>\n/ !~ `ruby ../../simple-complete.rb no_require.rb 12:5`)
	end
	
	# クラスを定義したファイルをrequireする場合のテスト
	def test_with_require
		# クラス名が補完に入るか
		assert_match(/(^|\n)ClassForTest\n/, `ruby ../../simple-complete.rb with_require.rb 5:1`)
		# 定数名を参照できるか
		assert_match(/(^|\n)TEST_CONST_VALIABLE\n/, `ruby ../../simple-complete.rb with_require.rb 6:15`)
		# インスタンス変数名を参照できるか。現状は未対応
#		assert_match(/(^|\n)@test_instance_valiable\b/, `ruby ../../simple-complete.rb with_require.rb 7:4`)
		# クラス変数名を参照できるか。
		assert_match(/(^|\n)@@test_class_valiable\n/, `ruby ../../simple-complete.rb with_require.rb 8:5`)
		# メソッド名を参照できるか
		assert_match(/(^|\n)test_method\n/, `ruby ../../simple-complete.rb with_require.rb 13:6`)
		# インクルードの処理ができているか
		assert_match(/(^|\n)cp_r\n/, `ruby ../../simple-complete.rb with_require.rb 12:4`)
	end
	
	# dabbrevのテスト
	def test_daddrev
		# dabbrevのテスト(@が含まれる文字)
		assert_match(/(^|\n)@teaaa\n/, `ruby ../../simple-complete.rb dabbrev.rb 6:3`)
		# dabbrevのテスト(@@が含まれる文字で、@の位置で補完を行った場合)
		assert_match(/(^|\n)@@teaaa\n/, `ruby ../../simple-complete.rb dabbrev.rb 7:2`)
		# dabbrevのテスト(?や!が含まれている文字列を補完するか)
		assert_match(/(^|\n)test!\n/, `ruby ../../simple-complete.rb dabbrev.rb 10:3`)
		assert_match(/(^|\n)test?\n/, `ruby ../../simple-complete.rb dabbrev.rb 10:3`)
		# 現在入力している文字を補完しないか
		assert(/(^|\n)te\n/ !~ `ruby ../../simple-complete.rb dabbrev.rb 10:3`)
		# 現在入力している文字を補完しないか(後ろに文字がある場合)
		assert(/(^|\n)aasda\n/ !~ `ruby ../../simple-complete.rb dabbrev.rb 11:3`)
	end
end
