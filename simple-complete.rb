# -*- coding: utf-8 -*-
# 
#   simple-complete.rb
# 
# rubyのスクリプトファイル及びファイル内の位置を指定し、その箇所の単語を補完したときの
# 候補を改行区切りで返します。候補がない場合は終了コードが1になります。

# 引数をパースする。optparseを使いたいが、補完候補に影響を及ぼしてしまうので使えない。
if ARGV.length == 2
	# 一つ目は必ずファイル名
	filepath = ARGV[0]
	# 二つめは行数とカラム位置の指定
	if /(\d+):(\d+)/ =~ ARGV[1]
		line_no = $1.to_i
		column_no = $2.to_i
	end
end

unless filepath && line_no && column_no
	puts "usage: ruby simple-complete.rb FILENAME LINE_NO:COLUMN_NO"
	exit
end

# 補完対象のファイルでrequireされているライブラリ
requires = []
# 補完対象のファイルでincludeされているモジュール
includes = []
# 補完対象がメソッドや定数だった場合のレシーバ。
# 存在しない場合はnil。存在するが不明な場合は空文字列。存在してわかっている場合は空でない文字列。
receiver = nil
# 補完対象にレシーバがあった場合に、その呼び出し方が定数の参照になっているかどうか。
# receiverがnilの場合は常にfalseである。
is_const_ref = false
# ヒント文字列。空文字の場合はヒントが得られなかったことを示す。
# nilの場合は行の指定が間違っていたことを示す。つまりエラー。
hint_str = nil

File.readlines(filepath).each_with_index do |line, index|
	if index == line_no
		target_str = line.unpack('C*')[0...column_no].pack('C*')
		if /(\.|::)([a-zA-Z0-9_]*)$/ =~ target_str
			is_const_ref = ($1 == "::")
			hint_str = $2
			if /([A-Z][a-zA-Z0-9_:]*)(\.|::)([a-zA-Z0-9_]*)$/ =~ target_str
				receiver = $1
			else
				receiver = ""
			end
		elsif /([@$]?@?[a-zA-Z0-9_]*)$/ =~ target_str
			hint_str = $1
		end
	else
		if /require\s+["'](.+)["']/ =~ line
			requires << $1
		elsif /include\s+([a-zA-Z0-9_:]+)/ =~ line
			includes << $1
		end
	end
end

# hint_strがnilの場合は行の指定が間違っている。ヒント文字列なしの補完として扱う。
unless hint_str
	hint_str = ""
end

# 補完対象のファイルのあるフォルダに移動
#Dir.chdir(File.dirname(filepath))

# 補完対象のファイルでrequireされているライブラリをrequireする(例外が起きても無視)
requires.each do |item|
	require item rescue nil
end

# 補完対象のファイルでincludeされているモジュールをincludeする(例外が起きても無視)
includes.each do |item|
	include item.split("::").inject(Object){|o,c| o.const_get(c)} rescue nil
end

# 補完候補を入れる配列
cands = []

# この時点で定義されているモジュールを全て取得する
# 再帰して全部やりたいが、循環してしまうことがあって難しいので1階層だけにする
# （Hoge::PiyoはいけるがHoge::Piyo::Fugaは含まれない）
modules = []
Module.constants.each do |item|
	# Kernelは組み込み関数になるので除く
	next if item == Kernel
	c = Module.const_get(item)
	if c.kind_of?(Module)
		c.constants.each do |subitem|
			subc = c.const_get(subitem)
			modules << subc if subc.kind_of?(Module)
		end
		modules << c
	end
end

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
		# $から始まっている、グローバル定数である
		cands.concat(global_variables)
	elsif /^@@/ =~ hint_str
		# @@から始まっている、何らかのクラスのクラス変数である
		modules.each do |item|
			cands.concat(item.class_variables)
		end
	elsif /^@/ =~ hint_str
		# @から始まっている、何らかのクラスのインスタンス変数である
		modules.each do |item|
			cands.concat(item.instance_variables)
		end
	else
		# この何れでもない。グローバル関数、もしくは定数である。
		Object.ancestors.each {|item| cands.concat(item.singleton_methods)}
		cands.concat(Module.constants);
	end
end

# hint_strがある場合は候補を絞り込む
if hint_str.length > 0
	cands.reject! {|item| item.index(hint_str) != 0}
end

# 候補がなかったらエラーで終了
exit(1) if cands.length == 0

# 候補をuniqし、sortした上で出力する
puts cands.uniq.sort
