#--*-coding:utf-8-*--

class Satasupe < DiceBot
  
  def initialize
    super
    @sendMode = 2
    @sortType = 1
    @d66Type = 2
  end
  def gameName
    'サタスペ'
  end
  
  def gameType
    "Satasupe"
  end
  
  def prefixs
    ['(\d+R|SR\d+|TAGT|\w+IET|\w+IHT|F\w*T|F\w*T|A\w*T|G\w*A\w*T|A\w*T|R\w*FT|NPCT|KusaiMT|EnterT|BudTT|GetgT|GetzT|GetnT|GetkT|GETSST).*']
  end
  
  def getHelpMessage
    return <<INFO_MESSAGE_TEXT
・判定コマンド　(nR>=x[y,z,c] or nR>=x or nR>=[,,c] etc)
　nが最大ロール回数、xが難易度、yが目標成功度、zがファンブル値、cが必殺値。
　y と z と c は省略可能です。(省略時、y＝無制限、z＝1、c=13(なし))
　c の後ろにSを記述すると必殺が出た時点で判定を終了します。
　例）5R>=5[10,2,7S]
・性業値コマンド(SRx or SRx+y or SRx-y x=性業値 y=修正値)
・各種表 ： コマンド末尾に数字を入れると複数回の一括実行が可能　例）TAGT3
　・タグ決定表(TAGT)
　・命中判定ファンブル表(FumbleT)、致命傷表(FatalT)
　・ロマンスファンブル表(RomanceFT)
　・アクシデント表(AccidentT)、汎用アクシデント表(GeneralAT)
　・その後表　(AfterT)、臭い飯表(KusaiMT)、登場表(EnterT)、
　　　バッドトリップ表(BudTT)
　・報酬表(Get〜) ： ガラクタ(GetgT)、実用品(GetzT)、値打ち物(GetnT)、
　　　奇天烈(GetkT)
　・NPCの年齢と好みを一括出力(NPCT)
　・「サタスペ」のベースとアクセサリを出力(GETSSTx　xはアクセサリ数、省略時１)
・以下のコマンドは +,- でダイス目修正、=でダイス目指定が可能
　例）CrimeIET+1　CrimeIET-1　CrimeIET=7
　・情報イベント表(〜IET) ： 犯罪表(CrimeIET)、生活表(LifeIET)、
　　　恋愛表(LoveIET)、教養表(CultureIET)、戦闘表(CombatIET)
　・情報ハプニング表(〜IHT) ： 犯罪表(CrimeIHT)、生活表(LifeIHT)、
　　　恋愛表(LoveIHT)、教養表(CultureIHT)、戦闘表(CombatIHT)
・D66ダイスあり
INFO_MESSAGE_TEXT
  end
  
  
  
  def rollDiceCommand(command)
    debug("rollDiceCommand begin string", command)
    
    result = ''
    
    result = checkRoll(command)
    return result unless(result.empty?)
    
    debug("判定ロールではなかった")
    
    
    result = check_seigou(command)
    return result unless(result.empty?)
    
    debug("〔性業値〕チェックでもなかった")
    
    
    debug("各種表として処理")
    return rollTableCommand(command)
  end
  
  
  def checkRoll(string)
    debug("checkRoll begin string", string)
    
    return '' unless(/^(\d+)R>=(\d+)(\[(\d+)?(,|,\d+)?(,\d+(S)?)?\])?$/i =~ string)
    
    roll_times = $1.to_i
    target = $2.to_i
    params = $3
    
    min_suc, fumble, critical, isCriticalStop = getRollParams(params)
    
    result = ""
    
    if(target > 12 )
      result  += "【#{string}】 ＞ 難易度が12を超えたため、超過分、ファンブル率が上昇！\n"
      while(target > 12)
        target = target - 1
        fumble = fumble + 1
      end
    end
    
    if(critical < 1 or critical > 12)
      critical = 13
    end
    
    if(fumble >= 6 )
      result += "#{getJudgeInfo(target, fumble, critical)} ＞ ファンブル率が6を超えたため自動失敗！"
      return result
    end
    
    if(target < 5 )
      result  += "【#{string}】 ＞ あらゆる難易度は5未満にはならないため、難易度は5になる！\n"
      target = 5
    end
    
    dice_str, total_suc, isCritical, isFumble = checkRollLoop(roll_times, min_suc, target, critical, fumble, isCriticalStop)
    
    result += "#{getJudgeInfo(target, fumble, critical)} ＞ #{dice_str} ＞ 成功度#{total_suc}"
    
    if( isFumble )
      result += " ＞ ファンブル"
    end
    
    if( isCritical and total_suc > 0 )
      result += " ＞ 必殺発動可能！"
    end
    
    debug( 'checkRoll result result', result )
    return result
  end
  
  
  def getRollParams(params)
    min_suc = 0
    fumble = 1
    critical = 13
	isCriticalStop = false
    
    # params => "[x,y,cS]"
    unless( params.nil? )
      if( /\[(\d*)(,(\d*)?)?(,(\d*)(S)?)?\]/ =~ params )
        min_suc = $1.to_i
        fumble = $3.to_i if( $3.to_i != 0 )
        critical = $5.to_i if( $4 )
        isCriticalStop = (not $6.nil? )
      end
    end
    
    return min_suc, fumble, critical, isCriticalStop
  end
  
  
  def getJudgeInfo(target, fumble, critical)
    "【難易度#{target}、ファンブル率#{fumble}#{getcriticalString(critical)}】"
  end
  
  def getcriticalString(critical)
    criticalString = (critical == 13 ? "なし" : critical.to_s)
    return "、必殺#{criticalString}"
  end
  
  
  def checkRollLoop(roll_times, min_suc, target, critical, fumble, isCriticalStop)
    dice_str = ''
    isFumble = false
    isCritical = false
    total_suc = 0
    
    roll_times.times do |i|
      debug('roll_times', roll_times)
    
      debug('min_suc, total_suc', min_suc, total_suc)
      if( min_suc != 0 )
        if(total_suc >= min_suc)
          debug('(total_suc >= min_suc) break')
          break
        end
      end
      
      d1, = roll(1, 6)
      d2, = roll(1, 6)
      
      dice_suc = 0
      dice_suc = 1 if(target <= (d1 + d2))
      dice_str += "+" unless( dice_str.empty? )
      dice_str += "#{dice_suc}[#{d1},#{d2}]"
      total_suc += dice_suc
      
      if(critical <= d1+d2)
        isCritical = true
        dice_str += "『必殺！』"
      end
      
      if((d1 == d2) and (d1 <= fumble))  # ファンブルの確認
        isFumble = true
        isCritical = false
        break
      end
      
      if(isCritical and isCriticalStop) #必殺止めの確認
        break
      end
      
    end
    
    return dice_str, total_suc, isCritical, isFumble
  end
  
  
  
  def check_seigou(string)
    debug("check_seigou begin string", string)
    
    return '' unless(/^SR(\d+)(([+]|[-])(\d+))?$/i =~ string)
    
    target = $1.to_i
    operator = $3
    value = $4.to_i
    
    dice,  = roll(2, 6)
    modify = 0
    
    unless( operator.nil? )
      modify = value  if( operator == "+")
      modify = value * (-1)  if( operator == "-")
    end
    
    diceTotal = dice + modify
    
    seigou = ""
    seigou = "「激」" if(target < diceTotal)
    seigou = "「迷」" if(target == diceTotal)
    seigou = "「律」" if(target > diceTotal)
    
    result = "〔性業値〕#{target}、「修正値」#{modify} ＞ ダイス結果：（#{dice}） ＞ #{dice}＋（#{modify}）＝#{diceTotal} ＞ #{seigou}"
    
    result += " ＞ 1ゾロのため〔性業値〕が1点上昇！" if( dice == 2 )
    result += " ＞ 6ゾロのため〔性業値〕が1点減少！" if( dice == 12 )
    
    debug( 'check_seigou result result', result )
    return result
  end
  
  
  ####################
  # 各種表
  
  def rollTableCommand(command)
    command = command.upcase
    result = []
    
    return result unless( /([A-Za-z]+)(\d+)?(([+]|[-]|[=])(\d+))?/ === command )
    
    command = $1
    counts = 1
    counts = $2.to_i if($2)
    operator = $4
    value = $5.to_i
    
    
    debug("rollDiceCommand command", command)
    
    case command
    when "TAGT"
      result = getTagTableResult(counts)
      
    when "GETSST"
      result = getCreateSatasupeResult(counts)
      
    when "NPCT"
      result = getNpcTableResult(counts)
    else
      result = getAnotherTableResult(command, counts, operator, value)
    end
    
    return result.join("\n")
  end
  
  
  def getTagTableResult(counts)
    name = "タグ決定表"
    table = [
             '情報イベント',
             'アブノーマル(サ)',
             'カワイイ(サ)',
             'トンデモ(サ)',
             'マニア(サ)',
             'ヲタク(サ)',
             '音楽(ア)',
             '好きなタグ',
             'トレンド(ア)',
             '読書(ア)',
             'パフォーマンス(ア)',
             '美術(ア)',
             'アラサガシ(マ)',
             'おせっかい(マ)',
             '好きなタグ',
             '家事(マ)',
             'ガリ勉(マ)',
             '健康(マ)',
             'アウトドア(休)',
             '工作(休)',
             'スポーツ(休)',
             '同一タグ',
             'ハイソ(休)',
             '旅行(休)',
             '育成(イ)',
             'サビシガリヤ(イ)',
             'ヒマツブシ(イ)',
             '宗教(イ)',
             '同一タグ',
             'ワビサビ(イ)',
             'アダルト(風)',
             '飲食(風)',
             'ギャンブル(風)',
             'ゴシップ(風)',
             'ファッション(風)',
             '情報ハプニング',
            ]
    
    result = []
    
    counts.times do |i|
      info, number = get_table_by_d66(table)
      text = "#{name}:#{number}:#{info}"
      result.push( text )
    end
    
    return result
  end
  
  
  
  def getCreateSatasupeResult(counts)
    debug("getCreateSatasupeResult counts", counts)
    
    name = "サタスペ作成"
    
    hit = 0
    damage = 0
    life = 0
    kutibeni = 0
    kiba = 0
    
    abilities = []
    
    baseParts = "#{name}：ベース部品："
    partsEffect = "部品効果："
    
    number1, = roll(1, 6)
    
    case number1
    when 1
      baseParts += "「紙製の筒」"
      partsEffect += "「命中：10、ダメージ：3、耐久度1」"
      hit = 10
      damage = 3
      life = 1
      
    when 2
      baseParts += "「木製の筒」"
      partsEffect += "「命中：9、ダメージ：3、耐久度2」"
      hit = 9
      damage = 3
      life = 2
      
    when 3
      baseParts += "「小型のプラスチック製の筒」"
      partsEffect += "「命中：9、ダメージ：4、耐久度2」"
      hit = 9
      damage = 4
      life = 2
      
    when 4
      baseParts += "「大型のプラスチック製の筒」"
      partsEffect += "「命中：8、ダメージ：3、耐久度2、両手」"
      hit = 8
      damage = 3
      life = 2
      abilities << "「両手」"
      
    when 5
      baseParts += "「小型の金属製の筒」"
      partsEffect += "「命中：9、ダメージ：4、耐久度3」"
      hit = 9
      damage = 4
      life = 3
      
    when 6
      baseParts += "「大型の金属製の筒」"
      partsEffect += "「命中：8、ダメージ：5、耐久度3、両手」"
      hit = 8
      damage = 5
      life = 3
      abilities << "「両手」"
    end
    
    armsTable =[
             [11, '「パチンコ玉」'],
             [12, '「釘や画鋲、針」'],
             [13, '「砂利や小石、ガラスの破片」'],
             [14, '「口紅」'],
             [15, '「バネやゼンマイ」'],
             [16, '「捻子やビス」'],
             [22, '「生ゴミ」'],
             [23, '「ゴム」'],
             [24, '「歯車」'],
             [25, '「歯や牙、骨」'],
             [26, '「ワイヤー」'],
             [33, '「メガネなどのレンズ」'],
             [34, '「マッチ」'],
             [35, '「ガムテープや接着剤」'],
             [36, '「洗濯ばさみ」'],
             [44, '「花火」'],
             [45, '「食玩」'],
             [46, '「真空管やトランジスタ」'],
             [55, '「エアコンプレッサ」'],
             [56, '「豆」'],
             [66, '「ガスボンベや殺虫剤」'],
            ]
    armsEffectTable = [
              [11, '「武器破壊」'],
              [12, '「毒」'],
              [13, '「散弾」'],
              [14, '「（判定前宣言）一度だけ必殺10」'],
              [15, '「フル」'],
              [16, '「ダメージ＋１」'],
              [22, '「衝撃」'],
              [23, '「ダメージ＋１」'],
              [24, '「リボルバー」'],
              [25, '「（判定前宣言）1D6回、ダメージ＋２」'],
              [26, '「耐久度＋１」'],
              [33, '「命中－１」'],
              [34, '「必殺12」'],
              [35, '「耐久度＋１」'],
              [36, '「命中－１」'],
              [44, '「弾幕1」'],
              [45, '「暗器」'],
              [46, '「神秘」'],
              [55, '「ダメージ＋１」'],
              [56, '「マヒ」'],
              [66, '「爆発3」'],
             ]
    
    baseParts += "  アクセサリ部品："
    
    counts.times do |i|
      
      number2 = d66(2)
      baseParts += get_table_by_number(number2, armsTable)
      partsEffect += get_table_by_number(number2, armsEffectTable)
      
      case number2
      when 11
        abilities << "「武器破壊」"
      when 12
        abilities << "「毒」"
      when 13
        abilities << "「散弾」"
      when 14
        kutibeni += 1
      when 15
        abilities << "「フル」"
      when 16, 23, 55
        damage += 1
      when 22
        abilities << "「衝撃」"
      when 24
        abilities << "「リボルバー」"
      when 25
        kiba, = roll(1, 6)
      when 26, 35
        life += 1
      when 33, 36
        hit -= 1
      when 34
        abilities << "「必殺12」"
      when 44
        abilities << "「弾幕1」"
      when 45
        abilities << "「暗器」"
      when 46
        abilities << "「神秘」"
      when 56
        abilities << "「マヒ」"
      when 66
        abilities << "「爆発3」"
      end
      
    end
    
    
    result = []
    result.push( baseParts )
    result.push( partsEffect )
    
    text = "完成品：サタスペ  （ダメージ＋#{damage}・命中#{hit}・射撃、"
    text += "「（判定前宣言）#{kutibeni}回だけ、必殺10」" if( kutibeni > 0 )
    text += "「（判定前宣言）#{kiba}回だけ、ダメージ＋２」" if( kiba > 0 )
    
    text += abilities.sort.uniq.join
    
    text += "「サタスペ#{counts}」「耐久度#{life}」）"
    
    result.push( text )
    
    return result
  end
   
  
  
  def getNpcTableResult(counts)
    #好み／雰囲気表
    lmood = [
             'ダークな',
             'お金持ちな',
             '美形な',
             '知的な',
             'ワイルドな',
             'バランスがとれてる',
            ]
    #好み／年齢表
    lage = [
            '年下が好き。',
            '同い年が好き。',
            '年上が好き。',
           ]
    #年齢表
    age = [
           '幼年', #6+2D6歳
           '少年', #10+2D6歳
           '青年', #15+3D6歳
           '中年', #25+4D6歳
           '壮年', #40+5D6歳
           '老年', #60+6D6歳
          ]
    agen = [
            '6+2D6',  #幼年
            '10+2D6', #少年
            '15+3D6', #青年
            '25+4D6', #中年
            '40+5D6', #壮年
            '60+6D6', #老年
           ]
    
    name = "NPC表:"
    
    result = []
    
    counts.times do |i|
      age_type, dummy = roll(1, 6)
      age_type -= 1
      
      agen_text = agen[age_type]
      age_num = agen_text.split(/\+/)
      
      total, dummy = rollDiceAddingUp( age_num[1] )
      ysold = total + age_num[0].to_i
      
      lmodValue = lmood[(rand 6)]
      lageValue = lage[(rand 3)]
      
      text = "#{name}#{age[age_type]}(#{ysold}歳):#{lmodValue}#{lageValue}"
      result.push(text)
    end
    
    return result
  end
  
  
  
  def getAnotherTableResult(command, counts, operator, value)
    result = []
    
    name, table = get2d6TableInfo(command)
    return result if( name.empty? )
    
    counts.times do |i|
      _, index = getTableIndex(operator, value, 2, 6)
      
      info = table[index - 2]
      text = "#{name}#{index}:#{info}"
      result.push(text)
    end
    
    return result
  end
  
  
  def getTableIndex(operator, value, diceCount, diceType)
    index = nil
    modify = 0
    
    case operator
    when "+"
      modify = value
    when "-"
      modify = value * (-1)
    when "="
      index = value
    end
    
    if( index.nil? )
      index, = roll(diceCount, diceType)
      index += modify
    end
    
    index = [index, diceCount * 1].max
    index = [index, diceCount * diceType].min
    
    return modify, index
  end  
  
  
  
  def get2d6TableInfo(command)
    
    name = ""
    table = []
    
    case command
    when /CrimeIET/i
      name = "情報イベント表／〔犯罪〕:"
      table = %w{
謎の情報屋チュンさん登場。ターゲットとなる情報を渡し、いずこかへ去る。情報ゲット！
昔やった仕事の依頼人が登場。てがかりをくれる。好きなタグの上位リンク（SL+2）を１つ得る。
謎のメモを発見……このターゲットについて調べている間、このトピックのタグをチーム全員が所有しているものとして扱う
謎の動物が亜侠を路地裏に誘う。好きなタグの上位リンクを２つ得る
偶然、他の亜侠の仕事現場に出くわす。口止め料の代わりに好きなタグの上位リンクを１つ得る
あまりに適切な諜報活動。コストを消費せず、上位リンクを３つ得る
その道の権威を紹介される。現在と同じタグの上位リンクを２つ得る
捜査は足だね。〔肉体点〕を好きなだけ消費する。その値と同じ数の好きなタグの上位リンクを得る
近所のコンビニで立ち読み。思わぬ情報が手に入る。上位リンクを３つ得る
そのエリアの支配盟約からメッセンジャーが1D6人。自分のチームがその盟約に敵対していなければ、好きなタグの上位リンクを２つ得る。敵対していれば、メッセンジャーは「盟約戦闘員（p.127）」となる。血戦を行え
「三下（p.125）」が1D6人現れる。血戦を行え。倒した数だけ、好きなタグの上位リンクを手に入れる
}
    when /LifeIET/i
      name = "情報イベント表／〔生活〕:"
      table = %w{
謎の情報屋チュンさん登場。ターゲットとなる情報を渡し、いずこかへ去る。情報ゲット！
隣の奥さんと世間話。上位リンクを４つ得る
ミナミで接待。次の１ターン何もできない代わりに、好きなタグの上位リンク（SL+2）を１つ得る
息抜きにテレビを見ていたら、たまたまその情報が。好きなタグの上位リンクを１つ得る
器用に手に入れた情報を転売する。《札巻》を１個手に入れ、上位リンクを３つ得る
情報を得るついでに軽い営業。〔サイフ〕を１回復させ、上位リンクを３つ得る
街の有力者からの突然の電話。そのエリアの盟約の幹部NPCの誰かと【コネ】を結ぶことができる
金をばらまく。〔サイフ〕を好きなだけ消費する。その値と同じ数の任意の上位リンクを得る
〔表の顔〕の同僚が思いがけないアドバイスをくれる。上位リンクを1D6つ得る
謎の情報屋チュンさんが、情報とアイテムのトレードを申し出る。DDの指定するアイテムを１つ手に入れると、どこからともなくチュンさんが現れる。そのアイテムをチュンさんに渡せば、情報ゲット！
ターゲットとは関係ないが、ドデかい情報を掘り当てる。その情報を売って〔サイフ〕が全快する
}
    when /LoveIET/i
      name = "情報イベント表／〔恋愛〕:"
      table = %w{
謎の情報屋チュンさん登場。ターゲットとなる情報を渡し、いずこかへ去る。情報ゲット！
恋人との別れ。自分に恋人がいれば、１人を選んで、お互いのトリコ欄から名前を消す。その代わり情報ゲット！
とびきり美形の情報提供者と遭遇。〔性業値〕判定で律になると、好きなタグの上位リンクを１つ得る
敵対する亜侠と第一種接近遭遇。キスのあとの濡れた唇から、上位リンクを３つ得る
昔の恋人がそれに詳しかったはず。その日の深夜・早朝に行動しなければ、好きなタグの上位リンク（SL+2）を１つ得る
情報はともかくトリコをゲット。データは「女子高生（p.122）」を使用する
関係者とすてきな時間を過ごす。好きなタグの上位リンクを１つ得る。ただし、次の１ターンは行動できない
持つべきものは愛の奴隷。自分のトリコの数だけ好きなタグの上位リンクを得る
自分よりも１０歳年上のイヤなやつに身体を売る。現在と同じタグの上位リンクを１つ得る
有力者からの突然のご指名。チームの仲間を１人、ランダムに決定する。差し出すなら、そのキャラクターは次の１ターン行動できない代わり、その後にそのキャラクターの〔恋愛〕と同じ数の上位リンクを得る
愛する人の死。自分に恋人がいれば、１人選んで、そのキャラクターを死亡させる。その代わり情報ゲット！
}
    when /CultureIET/i
      name = "情報イベント表／〔教養〕:"
      table = %w{
謎の情報屋チュンさん登場。ターゲットとなる情報を渡し、いずこかへ去る。情報ゲット！
ネットで幻のリンクサイトを発見。すべての種類のタグに上位リンクがはられる
間違いメールから恋が始まる。ハンドルしか知らない「女子高生（p.122）」と恋人（お互いのトリコ）の関係になる
新聞社でバックナンバーを読みふける。上位リンクを６つ得る
巨大な掲示板群から必要な情報をサルベージ。好きなタグの上位リンクを１つ得る
検索エンジンにかけたらすぐヒット。コストを消費せず、上位リンクを４つ得る
警察無線を傍受。興味深い。好きなタグの上位リンクを２つ得る
クールな推理がさえ渡る。〔精神点〕を好きなだけ消費する。その値と同じ数だけ好きなタグの上位リンクを得る
図書館ロールが貫通。好きなタグの上位リンク（SL+3)を１つ得る
図書館で幻の書物を発見。上位リンクを８つ得る。キャラクターシートのメモ欄に<クトゥルフ神話知識>、SANと記入し、それぞれ後ろに＋５、−５の数値を書き加える
アジトに謎の手紙が届く。自分のアジトに戻れば、情報ゲット！
}
    when /CombatIET/i
      name = "情報イベント表／〔戦闘〕:"
      table = %w{
謎の情報屋チュンさん登場。ターゲットとなる情報を渡し、いずこかへ去る。情報ゲット！
昔、お前が『更正』させた大幇のチンピラから情報を得る。〔精神点〕を２点減少し、好きなタグの上位リンク（SL+2）を１つ得る。
大阪市警の刑事から情報リーク。「敵の敵は味方」ということか……？　〔精神点〕を３点減少し、上位リンクを６つ得る。
無軌道な若者達を拳で『更正』させる。彼等は涙を流しながら情報を差し出した。……情けは人のためならず。好きなだけ〔精神点〕を減少する。減少した値と同じ数だけ、上位リンクを得る。
クスリ漬けの流氓を拳で『説得』。流氓はゲロと一緒に情報を吐き出した。２点のダメージ（セーブ不可）を受け、好きなタグの上位リンクを１つ得る。
次から次へと糞どもがやってくる。コストを消費せずに上位リンクを３つ得る。
自称『善良な一市民』からの情報リークを受ける。オマエの持っている異能の数だけ上位リンクを得る。……罠か！？
サウナ風呂でくつろぐヤクザから情報収集。ヤクザは歯の折れた口から、弱々しい呻きと共に情報を吐き出した。好きなだけダメージを受ける（セーブ不可）。好きなタグの受けたダメージと同じ値のSLへリンクを１つ得る。
ゼロ・トレランスオンスロートなラブ＆ウォー。2D6を振り、その値が現在の〔肉体点〕以上であれば、情報をゲット！
お前達を狙う刺客が冥土の土産に教えてくれる。お前自身かチームの仲間、お前の恋人のいずれかの〔肉体点〕を０点にすれば、情報をゲットできる。
お前の宿敵（データはブラックアドレス）が1D6体現れる。血戦によって相手を倒せば、情報ゲット。
}
    when /CrimeIHT/i
      name = "情報ハプニング表／〔犯罪〕:"
      table = %w{
謎の情報屋チュンさん登場。ターゲットとなる情報を渡し、いずこかへ去る。情報ゲット！
警官からの職務質問。一晩拘留される。臭い飯表（p.70）を１回振ること
だますつもりがだまされる。〔サイフ〕を１点消費
気のゆるみによる駐車違反。持っている乗物が無くなってしまう
超えてはならない一線を越える。トラウマを１点受ける
そのトピックを取りしきる盟約に目をつけられる。このトピックと同じタグのトピックからはリンクをはれなくなる
過去の亡霊がきみを襲う。自分の修得している異能の中から好きな１つを選ぶ。このセッションでは、その異能が使用不可になる
敵対する盟約のいざこざに巻き込まれる。〔肉体点〕に1D6点のセーブ不可なダメージを受ける
スリにあう。〔通常装備〕からランダムにアイテムを１個選び、それを無くす
敵対する盟約からの妨害工作。この情報は情報収集のルールを使って手に入れることはできなくなる
頼れる協力者のもとへ行くと、彼（彼女）の無惨な姿が……自分の持っている現在のセッションに参加していないキャラクター１体を選び、〔肉体点〕を０にする。そして、致命傷表(p.61）を振ること
}
    when /LifeIHT/i
      name = "情報ハプニング表／〔生活〕:"
      table = %w{
謎の情報屋チュンさん登場。ターゲットとなる情報を渡し、いずこかへ去る。情報ゲット！
経理の整理に没頭。この日の行動をすべてそれに費やさない限り、このセッションでは買物を行えなくなる
壮大なる無駄使い。〔サイフ〕を１点消費
「当たり屋(p.124）」が【追跡】を開始
留守の間に空き巣が！　〔アジト装備〕からランダムにアイテムが１個無くなる
「押し売り(p.124）」が【追跡】を開始
新たな風を感じる。自分の好きな〔趣味〕１つをランダムに変更すること
貧乏ひまなし。［1D6−自分の〔生活〕］ターンの間、行動できなくなる
留守の間にアジトが火事に！　〔アジト装備〕がすべて無くなる。明日からどうしよう？
頼りにしていた有力者が失脚する。しわ寄せがこっちにもきて、〔生活〕が１点減少する
覚えのない借金の返済を迫られる。〔サイフ〕を1D6点減らす。〔サイフ〕が足りない場合、そのセッション終了時までに不足分を支払わないと【借金大王】(p.119）の代償を得る
}
    when /LoveIHT/i
      name = "情報ハプニング表／〔恋愛〕:"
      table = %w{
謎の情報屋チュンさん登場。ターゲットとなる情報を渡し、いずこかへ去る。情報ゲット！
一晩を楽しむが相手はちょっと特殊な趣味だった。アブノーマルの趣味を持っていない限り、トラウマを１点受ける。この日はもう行動できない
一晩を楽しむが相手はちょっと特殊な趣味だった。【両刀使い】の異能を持っていない限り、トラウマを１点受ける。この日はもう行動できない
一晩を楽しむが相手は年齢を10偽っていた。ロマンス判定のファンブル表を振ること
すてきな人を見かけ、一目惚れ。DDが選んだNPC１体のトリコになる
「痴漢・痴女(p.124）」が【追跡】を開始
手を出した相手が有力者の女（ヒモ）だった。手下どもに袋叩きに会い、1D6点のダメージを受ける（セーブ不可）
突然の別れ。トリコ欄からランダムに１体を選び、その名前を消す
乱れた性生活に疲れる。〔肉体点〕と〔精神点〕がともに２点減少する
性病が伝染る。１日以内に病院に行き、治療（価格４）を行わないと、鼻がもげる。鼻がもげると〔恋愛〕が１点減少する
生命の神秘。子供ができる
}
    when /CultureIHT/i
      name = "情報ハプニング表／〔教養〕:"
      table = %w{
謎の情報屋チュンさん登場。ターゲットとなる情報を渡し、いずこかへ去る。情報ゲット！
アヤシイ書物を読み、一時的発狂。この日はもう行動できない。トラウマを１点受ける
天才ゆえの憂鬱。自分の〔教養〕と同じ値だけ、〔精神点〕を減少させる
唐突に睡魔が。次から２ターンの間、睡眠しなくてはならない
間違いメールから恋が始まる。ハンドルしか知らない「女子高生（p.122）」に偽装した「殺人鬼（p.137）」と恋人（お互いのトリコ）の関係になる
「勧誘員(p.124）」が【追跡】を開始
OSの不調。徹夜で再インストール。この日はもう行動できない上、「無理」をしてしまう
場を荒らしてしまう。このトピックと同じタグのトピックからはリンクをはれなくなる
ボケる。〔教養〕が１点減少する
クラッキングに遭う。いままで調べていたトピックとリンクをすべて失う
ネットサーフィンにハマってしまい、ついつい時間が過ぎる。毎ターンのはじめに〔性業値〕判定を行い、律にならないとそのターンは行動できない。この効果は１日続く
}
    when /CombatIHT/i
      name = "情報ハプニング表／〔戦闘〕:"
      table = %w{
謎の情報屋チュンさん登場。ターゲットとなる情報を渡し、いずこかへ去る。情報ゲット！
悪を憎む心に支配され、一匹の修羅と化す。キジルシの代償から１種類を選び、このセッションの間、習得すること。修得できるキジルシの代償がなければ、あなたはNPCとなる。
自宅に帰ると、無惨に破壊された君のおたからが転がっていた。「この件から手を引け」という書き置きと共に……。この情報フェイズでは、リンク判定を行ったトピックのタグの〔趣味〕を修得していた場合、それを未修得にする。また、おたからを持っていたなら、このセッション中、そのおたからは利用できなくなる。
「俺にはもっと別の人生があったんじゃないだろうか……！？」突如、空しさがこみ上げて来る……その日は各ターンの始めに〔性業値〕判定を行う。失敗すると、酒に溺れ、そのターンは行動済みになる。
クライムファイター仲間からスパイの容疑を受ける……１点のトラウマを追う。
自宅の扉にメモが……！！　「今ならまだ間に合う」奴等はどこまで知っているんだ！？　このトピックからは、これ以上リンクを伸ばせなくなる。
大幇とコンビナートの抗争に何故か巻き込まれる。……なんとか生還するが、次のターンの最後まで行動できず、1D6点のダメージを受ける（セーブ不可）
地獄組の鉄砲玉が君に襲い掛かってきた！！　〔戦闘〕で難易度９の判定に失敗すると、〔肉体点〕が０になる。
「お前はやり過ぎた」の書きおきと共に、友人の死体が発見される〔戦闘〕で難易度９の判定を行う。失敗すると、ランダムに選んだチームの仲間１人が死亡する。
宿敵によって深い疵を受ける。自分の修得している異能の中から、１つ選ぶこと。このセッションのあいだ、その異能を使用することができなくなる。
流氓の男の卑劣な罠にかかり、肥え喰らいの巣に落ちる！！　「掃き溜めの悪魔」1D6体と血戦を行う。戦いに勝たない限り、生きて帰ることはできないだろう……。もちろん血戦に勝ったところで情報は得られない。
}
    when /G(eneral)?A(ccident)?T/i
      name = "汎用アクシデント表:"
      table = %w{
痛恨のミス。激しく状況が悪化する。以降のケチャップに関する行為判定の難易度に＋１の修正がつき、あなたが追う側なら逃げる側のコマを２マス進める（逃げる側なら自分を２マス戻す）
最悪の大事故。ケチャップどころではない！　〔犯罪〕で難易度９の判定を行う。失敗したら、ムーブ判定を行ったキャラクターは3D6点のダメージを受け、ケチャップから脱落する。判定に成功すればギリギリ難を逃れる。特に何もなし。
もうダメだ……。絶望感が襲いかかってくる。後３ラウンド以内にケリをつけないと、あなたが追う側なら自動的に逃げる側が勝利する（逃げる側なら追う側が勝利する）
まずい、突発事故だ！　ムーブ判定を行ったキャラクターは、1D6点のダメージを受ける。
一瞬ひやりと緊張が走る。　ムーブ判定を行ったキャラクターは、〔精神点〕を２点減少する。
スランプ！　思わず足踏みしてしまう。ムーブ判定を行った者は、ムーブ判定に使用した能力値を使って難易度７の判定を行うこと。失敗したら、ムーブ判定を行ったキャラクターは、ケチャップから脱落。成功しても、あなたが追う側なら逃げる側のコマを１マス進める（逃げる側なら自分を１マス戻す）
イマイチ集中できない。〔性業値〕判定を行うこと。「激」になると、思わず見とれてしまう。あなたが追う側なら逃げる側のコマを１マス進める（逃げる側なら自分を１マス戻す）
古傷が痛み出す。以降のケチャップに関する行為判定に修正が＋１つく
うっかり持ち物を見失う。〔通常装備〕欄からアイテムを１個選んで消す
苦しい状態に追い込まれた。ムーブ判定を行ったキャラクターは、今後のムーブ判定で成功度が−１される。
頭の中が真っ白になる。〔精神点〕を1D6減少する。
}
    when /R(omance)?F(umble)?T/i
      name = "ロマンスファンブル表:"
      table = %w{
みんなあいそをつかす。自分のトリコ欄のキャラクターの名前をすべて消すこと
痴漢として通報される。〔犯罪〕の難易度９の判定に成功しない限り、1D6ターン後に検挙されてしまう
へんにつきまとわれる。対象は、トリコになるが、ファンブル表の結果やトリコと分かれる判定に成功しない限り、常備化しなくてもトリコ欄から消えることはない
修羅場！　対象とは別にトリコを所有していれば、そのキャラクターが現れ、あなたと対象に血戦をしかけてくる
恋に疲れる。自分の〔精神点〕が1D6点減少する
甘い罠。あなたが対象のトリコになってしまう
平手うち！　自分の〔肉体点〕が1D6点減少する
浮気がばれる。恋人関係にあるトリコがいれば、そのキャラクターの名前をあなたのトリコ欄から消す
無礼な失言をしてしまう。対象はあなたに対し「憎悪（p.120参照）」の反応を抱き、あなたはその対象の名前を書き込んだ【仇敵】の代償を得る
ショックな一言。トラウマを１点受ける
トリコからの監視！　このセッションの間、ロマンス判定のファンブル率が自分のトリコの所持数と同じだけ上昇する
}
    when /FumbleT/i
      name = "命中判定ファンブル表:"
      table = %w{
自分の持ち物がすっぽぬけ、偶然敵を直撃！　持っているアイテムを１つ消し、ジオラマ上にいるキャラクター１人をランダムに選ぶ。そのキャラクターの〔肉体点〕を1D6ラウンドの間０点にし、行動不能にさせる（致命傷表は使用しない）。1D6ラウンドが経過し、行動不能から回復すると、そのキャラクターの〔肉体点〕は、行動不能になる直前の値にまで回復する
敵の増援！　「三下(p.125）」が1D6体現れて、自分たちに襲いかかってくる（DDは、この処理が面倒だと思ったら、ファンブルしたキャラクターの〔肉体点〕を1D6点減少させてもよい）
お前のいるマスに「障害物」が出現！　そのマスに障害物オブジェクトを置き、そのマスにいたキャラクターは全員２ダメージを受ける（セーブ不可）
射撃武器を使っていれば、弾切れを起こす。準備行動を行わないとその武器はもう使えない
転んでしまう。準備行動を行わないと移動フェイズに行動できず、格闘、射撃、突撃攻撃が行えない
急に命が惜しくなる。性業値判定をすること。「激」なら戦闘を続行。「律」なら次のラウンドから全力移動を行い、ジオラマから逃走を試みる。「迷」なら次のラウンドは移動・攻撃フェイズに行動できない
誤って別の目標を攻撃。目標以外であなたに一番近いキャラクターに４ダメージ（セーブ不可）！
誤って自分を攻撃。３ダメージ（セーブ不可）！
今使っている武器が壊れる。アイテム欄から使用中の武器を消すこと。銃器を使っていた場合、暴発して自分に６ダメージ！　武器なしの場合、体を傷つけ３ダメージ（共にセーブ不可）！
「制服警官(p.129）」が１人現れる。その場にいるキャラクターをランダムに攻撃する
最悪の事態。〔肉体点〕を０にして、そのキャラクターは行動不能に（致命傷表は使用しない）
}
    when /FatalT/i
      name = "致命傷表:"
      table = %w{
死亡。
死亡。
昏睡して行動不能。1D6ラウンド以内に治療し、〔肉体点〕を１以上にしないと死亡。
昏睡して行動不能。1D6ターン以内に治療し、〔肉体点〕を１以上にしないと死亡。
大怪我で行動不能。体の部位のどこかを欠損してしまう。任意の〔能力値〕１つが１点減少。
大怪我で行動不能。1D6ターン以内に治療し、〔肉体点〕を１以上にしないと体の部位のどこかを欠損してしまう。任意の〔能力値〕１つが１点減少。
気絶して行動不能。〔肉体点〕の回復には治療が必要。
気絶して行動不能。１ターン後、〔肉体点〕が１になる。
気絶して行動不能。1D6ラウンド後、〔肉体点〕が１になる。
気絶して行動不能。1D6ラウンド後、〔肉体点〕が1D6回復する。
奇跡的に無傷。さきほどのダメージを無効に。
}
    when /AccidentT/i
      name = "アクシデント表:"
      table = %w{
ゴミか何かが降ってきて、視界を塞ぐ。以降のケチャップに関する判定に修正が＋１つく。あなたが追う側なら逃げる側のコマを２マス進める（逃げる側なら自分を２マス戻す）
対向車線の車（もしくは他の船、飛行機）に激突しそうになる。運転手は難易度９の〔精神〕の判定を行うこと。失敗したら、乗物と乗組員全員は3D6のダメージを受けた上に、ケチャップから脱落
ヤバイ、ガソリンがもうない！　後３ラウンド以内にケリをつけないと逃げられ（追いつかれ）ちまう
露店や消火栓につっこむ。その乗物に1D6ダメージ
一瞬ひやりと緊張が走る。〔精神点〕を２点減らす
何かの障害物に衝突する。運転手は難易度７の〔精神〕の判定を行うこと。失敗したら、乗物と乗組員全員は2D6ダメージを受けた上に、ケチャップから脱落。成功しても、あなたが追う側なら逃げる側のコマを１マス進める（逃げる側なら自分を１マス戻す）
走ってる途中に〔趣味〕に関する何かが目に映る。性業値判定を行うこと。「激」になると思わず見とれてしまう。あなたが追う側なら逃げる側のコマを１マス進める（逃げる側なら自分を１マス戻す）
軽い故障が起きちまった。以降のケチャップに関する行為判定に修正が＋１つく
うっかり落し物。〔通常装備〕欄からアイテムを１個選んで消す
あやうく人にぶつかりそうになる。運転手は難易度９の〔精神〕の判定を行う。失敗したら、その一般人を殺してしまう。あなたが追う側なら逃げる側のコマを１マス進める（逃げる側なら自分を１マス戻す）
信号を無視しちまったら後ろで事故が起きた。警察のサイレンが鳴り響いてくる。DDはケチャップの最後尾に警察の乗物を加えろ。データは「制服警官（p.129）」のものを使用
}
    when /AfterT/i
      name = "その後表:"
      table = %w{
ここらが潮時かもしれない。2D6を振り、その目が自分の修得している代償未満であれば、そのキャラクターは引退し、二度と使用できない
苦労の数だけ喜びもある。2D6を振り、自分の代償の数以下の目を出した場合、経験点が追加で１点もらえる
妙な恨みを買ってしまった。【仇敵】（p.95）を修得する。誰が【仇敵】になるかは、DDが今回登場したNPCの中から１人を選ぶ
大物の覚えがめでたい。今回のセッションに登場した盟約へ入るための条件を満たしていれば、その盟約に経験点の消費なしで入ることができる
思わず意気投合。今回登場したNPC１人を選び、そのキャラクターとの【コネ】（p.95）を修得する
今回の事件で様々な教訓を得る。自分の修得しているアドバンスドカルマの中から、汎用以外のものを好きなだけ選ぶ。そのカルマの異能と代償を、別な異能と代償に変更することができる
深まるチームの絆。今回のセッションでミッションが成功していた場合、【絆】（p.95）を修得する
色々な運命を感じる。今回のセッションでトリコができていた場合、経験点の消費なしにそのトリコを常備化することができる。また、自分が誰かのトリコになっていた場合、その人物への【トリコ】(p.95）の代償を得る
やっぱり亜侠も楽じゃないかも。今回のセッションで何かツラい目にあっていた場合、【日常】（p.95）を取得する
くそっ！　ここから出せ！！　今回のセッションで逮捕されていたら、【前科】(p.95）の代償を得る
〔性業値〕が１以下、もしくは１３以上だった場合、そのキャラクターは大阪の闇に消える。そのキャラクターは引退し、二度と使用できない
}
    when /KusaiMT/i
      name = "臭い飯表:"
      table = %w{
やあ署長、ご苦労さん。いつでも好きなときに留置所を出ることができる。
軽い取り調べを受ける。次の１ターンが終了するまで、未行動にならない。
荒っぽい取り調べを受ける。次の１ターンが終了するまで、未行動にならない。１ターン休み。1D6ダメージを受ける（セーブ不可）。
一晩泊まっていきなさい。次の日の朝まで未行動にならない。
粘り強い取り調べが続く。1D6日後の朝まで未行動にならない。
留置所のトイレで陵辱を受ける。1D6日後の朝まで未行動にならない。トラウマを１点受ける。
劣悪な環境のせいで伝染病にかかる。1D6日後の朝まで未行動にならない。【病弱】の代償を得る。
精神異常を訴え、無罪に。しかし、アーカム・アサイレムに移送され、1D6回別のキャラクターでセッションを行うまで、そのキャラクターを使用できない。キジルシの代償の中から、ランダムに１つの代償を得る。
起訴されて有罪に。海上刑務所行き。1D6回別のキャラクターでセッションを行うまで、そのキャラクターを使用できない。【前科】の代償を得る。
起訴されて有罪に。海上刑務所行き。2D6回別のキャラクターでセッションを行うまで、そのキャラクターを使用できない。【前科】の代償を得る。
起訴されて有罪に。海上刑務所行き。終身刑。そのキャラクターは引退する。
}
    when /EnterT/i
      name = "登場表:"
      table = %w{
「こっから先にはいかせないぜ」　【仇敵】がいれば現われ、血戦が始まる。現在の血戦、もしくはケチャップが終了したら、処理を行うこと。
「待たせたな、みんな！」　ジオラマの好きな場所に自分のキャラクターを配置する。
おっと、鉢合わせ。ランダムにジオラマ上の敵を１体選ぶ。選んだ敵と同じマスに、そのキャラクターを配置する。
全力ダッシュで駆けつける！　〔肉体点〕を1D6点消費すれば、ジオラマの好きな場所に自分のキャラクターを配置する。そうでなければ、登場できない。
裏道を歩いていたら、偶然その場所にでくわした。DDはジオラマの好きな場所にそのキャラクターを配置する。
「キキィー！」　もしもそのキャラクターが乗物を装備していれば、DDはジオラマの好きな場所にそのキャラクターを配置する。そうでなければ、登場できない。
……間に合ったみたいだな。仲間を１人選び、そのキャラクターと同じマスに自分のキャラクターを配置する。
ラッキー、「ジャリ銭」を拾った。……と、そんな場合じゃないよな。
をっと、お前の好物だ。〔性業値〕判定を行え。「律」ならもう一回、登場表を振ることができる。それ以外なら、キャラクターを配置できない。
んー。ここは一度通ったような。疲労から〔精神点〕を2点減少。
くあー。完全に道に迷っちまった。この実行フェイズには登場できない。
}
    when /BudTT/i
      name = "バッドトリップ表:"
      table = %w{
自分の身の周りにいる人たちが異様な何か(悪魔、宇宙人、ゾンビ、お前と同じ顔をした誰か…)に変貌し襲い掛かってくる。お前はNPCとなって、同じ場所にいる誰かに血戦をしかける。血戦が終了すれば（そして生きていれば）、視界は元に戻っている。
世界は一つ。オープンソース。愛で結びつくべきなんだ。お前は自分の知っていることをペラペラと話だし、1D6ターンの間、聞かれれば知っていることを何でも話してしまう。
自分と他人の区別がつかなくなり、現実感が薄れる。〔精神点〕を1D6点減少する。
誰かが自分を殺そうと企んでいるような錯覚を覚える。1D6ターンの間、ペテン師の代償【疑心暗鬼】を修得する。
風景が極彩色に彩られる！もっと……もっと極彩色に！もし他にも「麻薬」カテゴリのアイテムを持っていれば、その中の１個を使用する（行動は使わない）。
目の前にいる人物が非常にいとおしく思えてくる。同じ場所にいるキャラクターの中からランダムに１人選ぶ。1D6ターンの間、そのキャラクターのトリコになる。
魅力的な裸の異性が、あなたの目の前で誘惑する幻覚を見る。〔性業値〕判定を行う。「激」になると服を脱ぎだす。もしも外にいればそのエリアの〔治安〕の難易度の〔犯罪〕判定を行う。失敗すると「臭い飯」表を振る。
お前は痛みを感じなくなる。1D6ターンの間、〔肉体点〕の重症のペナルティが無効化される。
自分の持っているものから触手が生え、あなたにからみつく。自分の〔通常装備〕欄のアイテムの中からランダムに１種を選ぶ。それを捨てる。
皮膚の中を無数の蟲が蠢いているのを感じる。〔肉体点〕を３点減少する。
神々しい声が聞こえてくる。1D6ターンの間、自分の好きな能力値を１点上昇することができる。
}
    when /GetgT/i
      name = "報酬・ガラクタ表:"
      table = %w{
持ち主の〔生活〕と等しい個数の《食事》（基本80p、小道具・日用品）
持ち主の〔生活〕と等しい個数の《トルエン》（基本79p、小道具・麻薬）
持ち主の〔生活〕と等しい個数の《ジャリ銭》（基本78p、小道具・お金）
壊れた実用品。実用品表で決定。（壊れたアイテムは、１ターン使用し〔教養〕で難易度９の判定に使用すると直せる）
《テレカ》（基本78p、小道具・通信手段）
何もなかった（涙）。残念でした。
《ロープ》（基本78p、小道具・保安器具）
《トヨトミピストル》（基本74p、武器）
《自転車》（基本76p、乗物）
《ふとん》（基本79p、小道具・日用品）
持ち主の〔趣味〕からランダムに１種類選ぶ。その趣味おたからを１個ランダムに選ぶ。
}
    when /GetzT/i
      name = "報酬・実用品表:"
      table = %w{
持ち主と同じタイプの汎用おたから（基本82p、汎用おたから）
価格５の《ホテル》の使用券（基本80p、小道具・サービス）
《苦力》（基本80p、小道具・手下）
《カメラ》（基本80p、小道具・手下）
持ち主が使っていた装備（ただし、一般アイテムに存在しない装備をＰＣは使用できない）
持ち主の〔生活〕と等しい個数の《札巻》（基本78p、小道具・お金）
持ち主の〔生活〕と等しい個数の《大麻》（基本79p、小道具・麻薬）
《ノートパソコン》と《携帯電話》（基本78p、79p、小道具・日用品、通信手段）
《ヴェスパ》（基本76p、乗物）
《救急箱》（基本79p、小道具・保安器具）
《札束》（基本78p、小道具・お金）
}
    when /GetnT/i
      name = "報酬・値打ち物表:"
      table = %w{
社会的身分。【日常】の異能を手に入れる。
《人柱》（基本184p、盟約おたから・沙京流氓）
貴重な貴金属。１ターン使って〔生活〕で難易度９の判定に成功すれば《トランク》と交換できる。
持ち主と同じタイプの汎用おたから（基本82p、汎用おたから）
持ち主の〔生活〕と等しい個数の《ヘロイン》（基本79p、小道具・麻薬）
持ち主の〔生活〕と等しい個数の《札束》（基本78p、小道具・お金）
持ち主の〔生活〕と等しい個数の価格５以下の武器（基本79p、小道具・麻薬）
《ロールスロイス》（基本76p、乗物）
持ち主の〔趣味〕からランダムに１種類選ぶ。その趣味おたからを１個ランダムに選ぶ。
《トランク》（基本78p、小道具・お金）
《宝箱》（基本78p、小道具・お金）
}
    when /GetkT/i
      name = "報酬・奇天烈表:"
      table = %w{
好きな盟約おたから１個（プレイヤー全員で相談して決定）
《気球》（基本76p、乗物）
《チェインソー》（基本74p、武器）
誰かから感謝される。それだけ？
持ち主の〔趣味〕からランダムに１種類選ぶ。その趣味おたからを１個ランダムに選ぶ。
何もなかった（涙）。残念でした。
持ち主と同じタイプの汎用おたから（基本82p、汎用おたから）
《フォークリフト》（基本76p、乗物）
《RPG-7》（基本74p、武器）
倒されたキャラクターは、致命傷表を振り、まだ生きていれば、そのキャラクターを倒した者のトリコになる。
「先にイッてるぜ」そのキャラクター１体を倒した者に経験点が１点与えられる。
}
    end
    
    return name, table
  end
  
end
