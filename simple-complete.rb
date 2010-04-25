# -*- coding: utf-8 -*-
# 
# usage:
#   ruby simple-complete.rb FILENAME LINE_NO:COLUMN_NO
# 
# rubyのスクリプトファイル及びファイル内の位置を指定し、その箇所の単語を補完したときの
# 候補を改行区切りで返します。候補がある場合は終了コードが0に、ない場合は1になります。
# LINE_NOとCOLUMN_NOは1始まりです。また、COLUMN_NOは文字単位ではなくバイト単位で指定してください。

# 引数をパースする。optparseを使いたいが、補完候補に影響を及ぼしてしまうので使えない。
if ARGV.length == 2
	# 一つ目は必ずファイル名
	filepath = ARGV[0]
	# 二つめは行数とカラム位置の指定
	if /(\d+):(\d+)/ =~ ARGV[1]
		line_no = $1.to_i - 1
		column_no = $2.to_i - 1
	end
end

unless filepath && line_no && column_no
	puts "usage: ruby simple-complete.rb FILENAME LINE_NO:COLUMN_NO"
	puts "  LINE_NO and COLUMN_NO is one origin, and COLUMN_NO is counted by bytes."
	exit
end

# 補完で使用する予約語のリスト
reserved_words = %w|BEGIN class ensure nil self when END def false not super while alias defined? for or then yield and do if redo true begin else in rescue undef break elsif module retry unless case end next return until|
# 1.9ではシンボルにする
if RUBY_VERSION >= "1.9.0"
	reserved_words = reserved_words.map {|item| item.intern}
end

# 補完対象のファイルでrequireされているライブラリ
requires = []
# 補完対象のファイルで定義、もしくは継承されているクラス
class_names = []
# 補完対象のファイルでincludeされているモジュール
includes = []
# 補完対象がメソッドや定数だった場合のレシーバ。
# 存在しない場合はnil。存在するが不明な場合は空文字列。存在してわかっている場合は空でない文字列。
receiver = nil
# 補完対象にレシーバがあった場合に、その呼び出し方が定数の参照になっているかどうか。
# receiverがnilの場合は常にfalseである。
is_const_ref = false
# ヒント文字列。空文字の場合はヒントが得られなかったことを示す。
# nilの場合は行の指定が間違っていたことを示す。
hint_str = nil
# ヒント文字列の後ろに続く文字。dabbrevを行うために取得する。
back_hint_str = ""

# 補完対象のファイルを読み出す
content = File.read(filepath)

# このプログラムでは文字列はバイナリ列として扱う。1.9ではエンコーディングを指定する必要がある
if RUBY_VERSION >= "1.9.0"
	content.force_encoding(Encoding::ASCII_8BIT)
end

# 補完対象のファイルを読み込んで、補完文字、require、include等の情報を取得する
content.lines.each_with_index do |line, index|
	if index == line_no
		# 指定された行、補完文字の情報を取得
		target_str = line[0...column_no]
		if /(\.|::)([a-zA-Z0-9_]*)$/ =~ target_str
			# 補完する文字にレシーバーがいる。ヒント文字列と定数の参照か否かを取得する
			is_const_ref = ($1 == "::")
			hint_str = $2
			if /([A-Z][a-zA-Z0-9_:]*)(\.|::)([a-zA-Z0-9_]*)$/ =~ target_str
				receiver = $1
			else
				receiver = ""
			end
		elsif /([@$]?@?[a-zA-Z0-9_]*)$/ =~ target_str
			# レシーバーがいない、ヒント文字列のみを取得
			hint_str = $1
		end
		# ヒント文字列の後ろに続く文字があれば取得
		target_str = line[column_no..(-1)]
		if target_str
			if /[a-zA-Z0-9_]*[a-zA-Z0-9_!?]/ =~ target_str
				back_hint_str = $&
			end
		end
	end
	if /require\s+["'](.+)["']/ =~ line
		# requireしているファイル名を取得
		requires << $1
	elsif /class\s+([a-zA-Z0-9_:]+)/ =~ line
		# 定義されているクラスを取得
		class_names << $1
		# もし何らかのクラスを継承していたら取得
		if /<\s+([a-zA-Z0-9_:]+)/ =~ line
			class_names << $1
		end
	elsif /include\s+([a-zA-Z0-9_:]+)/ =~ line
		# includeしているモジュール名を取得
		includes << $1
	end
end

# hint_strがnilの場合は行の指定が間違っている。ヒント文字列なしの補完として扱う。
unless hint_str
	hint_str = ""
end

# 補完対象のファイルでrequireされているライブラリをrequireする(例外が起きても無視)
requires.each do |item|
	begin
		if /^test[\/_]/ =~ item
			# test/unit及びそれをrequireしたファイルをrequireするとテストの処理が始まってしまうため、特殊処理
			# 代わりにtest/unit/testcaseをrequireする
			require 'test/unit/testcase'
		else
			require item
		end
	rescue Exception
	end
end

# class_namesでconst_getして、実際のクラスに変換する(例外が起きても無視)
classes = []
class_names.each do |item|
	begin
		classes.concat(item.split("::").inject(Object){|o,c| o.const_get(c)}.ancestors)
	rescue Exception
	end
end
# uniqし、Kernelを除く
classes.uniq!
classes.delete(Kernel)

# 補完対象のファイルでincludeされているモジュールをincludeする(例外が起きても無視)
includes.each do |item|
	begin
		include item.split("::").inject(Object){|o,c| o.const_get(c)}
	rescue Exception
	end
end

# 補完候補を入れる配列
cands = []

# この時点で定義されているモジュールを全て取得する
# 再帰して全部やりたいが、循環してしまうことがあって難しいので2階層だけにする
# （Hoge::Piyo::Fugaは含まれるがHoge::Piyo::Fuga::Namuは含まれない）
modules = []
Module.constants.each do |item|
	c = Module.const_get(item)
	if c.kind_of?(Module)
		c.constants.each do |subitem|
			subc = c.const_get(subitem)
			if subc.kind_of?(Module)
				subc.constants.each do |subsubitem|
					subsubc = subc.const_get(subsubitem)
					modules << subsubc if subsubc.kind_of?(Module)
				end
				modules << subc
			end
		end
		modules << c
	end
end
# uniqし、Kernelを除く
modules.uniq!
modules.delete(Kernel)

# 状況に応じて候補を取得する
if receiver
	if receiver.length > 0
		if /[A-Z][a-zA-Z0-9_]*$/ =~ receiver
			# レシーバが定数である
			# ネストしている場合を考慮して取得
			receiver_module = receiver.split("::").inject(Object){|o,c| o.const_get(c)} rescue nil
			if receiver_module
				if is_const_ref
					# 定数を取得
					cands.concat(receiver_module.constants)
				else
					# クラスメソッドを取得
					cands.concat(receiver_module.singleton_methods)
					# newはsingleton_methodsでは出てこないので別途追加する。ただしclassの場合のみ
					if receiver_module.kind_of?(Class)
						cands << "new"
					end
				end
			end
		end
	end
	
	if cands.length == 0
		# ここまでの段階で候補がない場合
		# レシーバーの型が不明だったり、型の取得に失敗したときはここに来る
		if is_const_ref
			# 何れかのモジュールの定数
			modules.each do |item|
				cands.concat(item.constants)
			end
		else
			# 何れかのモジュールのメソッド
			modules.each do |item|
				cands.concat(item.instance_methods(false))
			end
		end
	end
else
	# レシーバーがない場合
	if /^[A-Z]/ =~ hint_str
		# 大文字から始まっている、定数である
		cands.concat(Module.constants)
	elsif /^\$/ =~ hint_str
		# $から始まっている、グローバル変数である
		cands.concat(global_variables)
	elsif /^@@/ =~ hint_str
		# @@から始まっている、何らかのクラスのクラス変数である
		modules.each do |item|
			cands.concat(item.class_variables)
		end
	elsif /^@/ =~ hint_str
		# @から始まっている、何らかのクラスのインスタンス変数である
		# インスタンス変数の補完は現状未対応
	elsif /[a-z_]/ =~ hint_str
		# 小文字、もしくはアンダーバーから始まっている。
		# グローバル関数、補完対象のファイルで定義しているクラスのメソッド、もしくは予約語である。
		Object.ancestors.each {|item| cands.concat(item.singleton_methods)}
		classes.each do |item|
			cands.concat(item.instance_methods(false))
		end
		cands.concat(reserved_words);
	elsif hint_str.length == 0
		# ヒント文字列が空文字。レシーバーがない場合のあらゆる可能性がある。
		cands.concat(Module.constants)
		cands.concat(global_variables)
		modules.each do |item|
			cands.concat(item.class_variables)
		end
		Object.ancestors.each {|item| cands.concat(item.singleton_methods)}
		classes.each do |item|
			cands.concat(item.instance_methods(false))
		end
		cands.concat(reserved_words);
	end
end

# 候補の絞り込みを行う
if hint_str.length > 0
	# 1.9ではメソッドや定数を取得するメソッドがシンボルを返すため、互換のためにto_sを挟む必要がある
	cands.reject! {|item| item.to_s.index(hint_str) != 0}
else
	# ヒント文字列がない場合、演算子オーバーライドのメソッドが入ってくるため、それを除く
	cands.reject! {|item| /^[$@a-zA-Z0-9_]/ !~ item.to_s}
end

# hint_strがある場合はdabbrevを行う
if hint_str.length > 0
	### dabbrevを行う
	dabbrev_cands = content.scan(/#{hint_str}@?[a-zA-Z0-9_]*[a-zA-Z0-9_!?]/)
	# 自分がいま入力しているものは省く
	dabbrev_cands.delete(hint_str + back_hint_str)
	# 全体の候補に加える(1.9ではシンボルにする)
	if RUBY_VERSION >= "1.9.0"
		cands.concat(dabbrev_cands.map {|item| item.intern})
	else
		cands.concat(dabbrev_cands)
	end
end

# 候補がなかったらエラーで終了
exit(1) if cands.length == 0

# 候補をuniqし、sortした上で出力する
puts cands.uniq.sort
