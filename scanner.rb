require 'net/https'
require 'uri'
require 'json'
require 'fileutils'
# Non-distributable file to decrypt ShinyColors resources.
require './local/blob_master'
require_relative 'zlib-ext'

# Adjust the value of these constants to change the character specification

# Character name to fetch from commu dialogues.
WHITELISTED_CHARA = %w(結華)
# Character ID to fetch
TARGET_CHARA_ID = 6
# Unit ID to fetch (this may be ignored)
TARGET_UNIT_ID  = 2

# END OF ADJUSTABLE CONSTANTS

UNIT_MEMBERS = [
  [1, 2, 3],
  [4, 5, 6, 7, 8],
  [9, 10, 11, 12, 13],
  [14, 15, 16],

  [17, 18, 19],
  [20, 21, 22, 23],
  [24, 25],
  [26]
]

COMMU_CATEGORY_KEY = {
  'special_communication' => 'specialCommunication',
  'birthday_event' => 'specialCommunication',
  'seasonal_event' => 'specialCommunication',
  'seasonal_present_event' => 'specialCommunication',
  'present_event' => 'specialCommunication',
  'idol_event' => 'event',
  'after_event' => 'event',
  'support_idol_event' => 'event',
  'character_event' => 'event',
  'season_event' => 'event',
  'unit_event' => 'event',
  'concert_event' => 'concertEvent',
  'communication_morning' => 'communication',
  'communication_cheer' => 'communicationCheer',
  'communication_audition' => 'communicationAudition',
  'communication_television' => 'communicationTelevision',
}

COMMU_DATA_PATH = {
  'event' => 'produce_events',
  'produceEndingEvent' => 'produce_events',
  'seasonalCommunicationEvent' => 'special_communications',
  'concertEvent' => 'produce_events',
  'communication' => 'produce_communications',
  'communicationPromise' => 'produce_communications_promises',
  'communicationPromiseResult' => 'produce_communication_promise_results',
  'communicationPromiseRecover' => 'produce_communication_promise_results',
  'communicationCheer' => 'produce_communication_cheers',
  'communicationTelevision' => 'produce_communication_televisions',
  'communicationAudition' => 'produce_communication_auditions',
  'supportSkill' => 'support_skills',
  'specialCommunication' => 'special_communications',
}

def encode_link(url)
  ext = File.extname(url)
  case ext
  when '.m4a', '.mp4', '.ogg', '.mp3';
  else ext = ''
  end
  "https://shinycolors.enza.fun/assets/%s%s" % [
    MstShinyColors::BlobMaster.encrypt_path(url), ext
  ]
end

def event_commu_link(commu_group, commu_id)
  "/assets/json/#{commu_group}/#{commu_id}.json"
end

def character_voice_link(chara_id, key)
  sprintf("/assets/sounds/voice/characters/%03d/%s.m4a", chara_id, key)
end

def card_voice_link(card_id, key)
  sprintf("/assets/sounds/voice/idols/%d/%s.m4a", card_id, key)
end

def create_if_not(dir_name)
  FileUtils.mkdir_p(dir_name) unless File.directory?(dir_name)
end

# This function is improved from site-saijue-coldbell-heaven's version.
# Specific to this function there may restrictions imposed to this.
# Please do not use this piece of code unless permission granted.
def download_if_not(fn, url, decrypt: false, fine404: false)
  return if File.exists?(fn)
  base_uri = URI('https://shinycolors.enza.fun')
  request_uri = URI(url)
  Net::HTTP.start(base_uri.host, base_uri.port, use_ssl: base_uri.scheme == 'https') do |http|
    req = Net::HTTP::Get.new(request_uri.path)
    req['Accept-Encoding'] = 'gzip, deflate, br' unless decrypt
    req['User-Agent'] = 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:52.0) Gecko/20100101 Firefox/52.0'
    res = http.request(req)
    if res.content_type == 'text/html' then
      $stderr.puts "#{request_uri.path} not found"
      return if fine404
      fail "404"
    end
    res.value
    if decrypt then
      begin
        File.write(fn, MstShinyColors::BlobMaster.decrypt_resource(res.body))
      rescue => e
        p res.body.slice(0, 50)
        fail e
      end
    else
      # res.header.each do |k,v| p "#{k}: #{v}" end
      case res['Content-Encoding']
      when /gzip$/i
        File.binwrite(fn, Zlib.gunzip_hard(res.body))
      else
        File.binwrite(fn, res.body)
      end
    end
  end
ensure
  puts url if $!
end

def process_commu(commu_folder, commu_type, commu_id)
  file_scenario = File.join(commu_folder, 'scenario.json')
  create_if_not commu_folder
  can_skip = !File.exists?(file_scenario)
  puts "  Downloading #{event_commu_link(commu_type, commu_id)}" unless File.exists?(file_scenario)
  download_if_not file_scenario,
    encode_link(event_commu_link(commu_type, commu_id)),
    decrypt: true
  
  return unless File.exists? file_scenario
  data_scenario = JSON.parse(File.read(file_scenario))
  data_scenario.each do |commu_instr|
    next unless commu_instr.key? 'speaker'
    next unless WHITELISTED_CHARA.include? commu_instr['speaker']
    next unless commu_instr.key? 'voice'
    
    voice_asset = File.join(
      '',
      'assets',
      'sounds/voice/events',
      commu_instr['voice'] + ".m4a"
    )
    voice_file = File.join(commu_folder, File.basename(voice_asset))
    can_skip |= !File.exists?(voice_file)
    unless File.exists?(voice_file)
      puts "  Downloading #{voice_asset}"
    end
    download_if_not voice_file,
      encode_link(voice_asset)
  end
  can_skip
end

Dir.chdir(__dir__) do
  GC.start
  album_data = JSON.parse(File.read('data/album.json'))
  
  [
    %w(gameEvents game_event_communications),
    %w(specialEvents special_communications),
  ].each do |(event_type, event_folder)|
    create_if_not event_type
    album_data[event_type].sort_by! do |x| x['id'].to_i(10) end
    commu_lines = []
    album_data[event_type].each do |game_event|
      folder_scenario = File.join(
        event_type,
        sprintf("%04d_%s", game_event['id'], game_event['name']).gsub(%r([*:/\\?]), '').strip
      )
      create_if_not folder_scenario
      game_event['communications'].each do |game_comm|
        puts "#{game_event['name']} - #{game_comm['name']}"
        can_skip = false
        folder_comm = File.join(
          folder_scenario,
          sprintf("%d_%s", game_comm['id'], game_comm['name']).gsub(%r([*:/\\?]), '').strip
        )
        can_skip |= process_commu(
          folder_comm,
          event_folder,
          game_comm['id'],
        )
      ensure
        can_skip &= $!.nil?
        sleep 8.0 if can_skip
      end
    end
    commu_lines.uniq!
    File.open("data/#{event_type}.csv", "w") do |f|
      commu_lines.each do |line|
        f.write line.join("\t")
        f.write "\n"
      end
    end if false
  end
  
  album_data.clear
  
  mapping_names = {}
  
  chara_list = JSON.parse(File.read('data/chara.json'))
  # Provide blanks for extended card data if it's not provided.
  # Though, this is a vital item as well.
  if File.exists?('data/consolidated.cards.json') then
    extended_card_data = JSON.parse(File.read('data/consolidated.cards.json'))
  else
    extended_card_data = {
      'idol_data' => [],
      'support_idol' => [],
    }
  end
  create_if_not 'characters'
  chara_list.each do |chara_data|
    next if chara_data['id'].to_i(10) != TARGET_CHARA_ID
    
    chara_folder = File.join('characters', sprintf("%03d", chara_data['id']))
    create_if_not chara_folder
    
    puts "(#{chara_data['id']}) generating birthday voices..."
    UNIT_MEMBERS[chara_data['unitId'].to_i.pred].each do |other_chara_id|
      next if other_chara_id == chara_data['id'].to_i
      dummy_entry = {
        "animation1" => "anger1",
        "animation2" => "face_serious",
        "animation3" => "",
        "animation3loop" => "",
        "animation4" => "",
        "availableExchangeSince" => 0,
        "canChangeIsEnabled" => false,
        "canReleaseWithItem" => false,
        "characterTrustLevelComment" => nil,
        "isEnabled" => true,
        "isReleased" => true,
        "lip" => "lip_wait",
        "releasedConditionComment": "Dummyの誕生日時にホーム画面で再生",
        "title" => "誕生日お祝いボイス（Dummy　誕生日）",
        "voice" => "mypage_007_birthday_004_0010",
        "voiceId" => "100007000041",
        "voiceType" => "mypageComment",
        "detailPopTextKey" => "voiceDetailPop"
      }
      dummy_entry['voice'] = sprintf('mypage_%03d_birthday_%03d_%03d0', chara_data['id'], other_chara_id, 1)
      dummy_entry['voiceId'] = sprintf('100%03d00%03d%d', chara_data['id'], other_chara_id, 1)
      chara_data['voices'] << dummy_entry
    end
    
    puts "(#{chara_data['id']}) generating reliance voices..."
    1.upto(11) do |reliance_lv|
      reliance_key = sprintf("%03d_reliance_%03d0", chara_data['id'], reliance_lv)
      next if chara_data['voices'].any? do |cv| cv['voice'] == reliance_key end
      chara_data['voices'].select do |cv| cv['voice'].start_with?(sprintf("%03d_reliance", chara_data['id'])) end
        .max_by do |cv| cv['voice'] end
        .tap do |reliance_max|
          reliance_max_idx = chara_data['voices'].find_index(reliance_max)
          reliance_dummy = reliance_max.dup
          reliance_dummy['voice'] = reliance_key
          reliance_dummy['voiceId'] = sprintf("%d%02d%03d", chara_data['id'], reliance_lv.succ, 1)
          reliance_dummy['title'] = sprintf("信頼度Lv.%dボイス", reliance_lv.succ)
          chara_data['voices'].insert reliance_max_idx.succ, reliance_dummy
        end
    end
    
    puts "(#{chara_data['id']}) generating unlisted voices..."
    unlisted_voices = []
    %w(
      concert inventory rest_boost
      success_amime
      support_success support_failure
      excellent support_excellent
      audition
    ).each do |k|
      1.upto(3) do |i|
        unlisted_voices << sprintf('%03d_%s_%d', TARGET_CHARA_ID, k, i)
      end
    end
    %w(
      promise_recover rest_boost tension_boost
      stamina_boost
      failure success
    ).each do |k|
      unlisted_voices << sprintf('%03d_%s_cutin', TARGET_CHARA_ID, k)
    end
    
    %w(start attack damage skil_select memory_appeal_success special_passive_skill).each do |k|
      1.upto(2) do |i|
        unlisted_voices << sprintf('concert_%s_%d', k, i)
      end
    end
    %w(
      finish
      meter_good meter_perfect meter_bad meter_miss
      last_appeal memory_appeal_select
      buff debuff
    ).each do |k|
      unlisted_voices << sprintf('concert_%s', k)
    end
    %w(s a b c d e f).each do |r|
      unlisted_voices << sprintf('%03d_idol_rank_%s',TARGET_CHARA_ID, r)
    end
    1.upto(15) do |i|
      unlisted_voices << sprintf('%03d_fes_top_%d',TARGET_CHARA_ID, i)
    end
    1.upto(5) do |i|
      unlisted_voices << sprintf('%03d_title_%d',TARGET_CHARA_ID, i)
    end
    unlisted_voices.each do |voice_name|
      voice_folder = File.join(chara_folder, 'unlisted')
      voice_link   = character_voice_link(chara_data['id'], voice_name)
      voice_file   = File.join(voice_folder, voice_name + '.m4a')
      create_if_not voice_folder
      can_skip = !File.exists?(voice_file)
      puts "  Downloading #{voice_name}" unless File.exists?(voice_file)
      download_if_not voice_file, encode_link(voice_link), fine404: true
    end
    
    puts "(#{chara_data['id']}) checking voices..."
    chara_data['voices'].each do |chara_voice|
      voice_folder = File.join(chara_folder, chara_voice['voiceType'])
      voice_link   = character_voice_link(chara_data['id'], chara_voice['voice'])
      voice_file   = File.join(voice_folder, chara_voice['voice'] + '.m4a')
      create_if_not voice_folder
      unless mapping_names.key?(voice_file)
        mapping_names[voice_file] = chara_voice['title'].sub('（Dummy　誕生日）', '(Dummy Entry)')
      end
      can_skip = !File.exists?(voice_file)
      puts "  Downloading #{chara_voice['voice']}" unless File.exists?(voice_file)
      download_if_not voice_file, encode_link(voice_link)
    ensure
      can_skip &= $!.nil?
      sleep 1.0 if can_skip
    end
    
    puts "(#{chara_data['id']}) checking personal commus..."
    chara_data['communications'].each do |chara_commu|
      commu_g_folder = File.join(chara_folder, chara_commu['albumType'])
      commu_e_folder = File.join(commu_g_folder, chara_commu['communicationId'])
      create_if_not commu_g_folder
      create_if_not commu_e_folder
      can_skip = false
      commu_file = File.join(commu_e_folder, 'scenario.json')
      mapping_names[commu_e_folder] = chara_commu['title']
      can_skip |= process_commu(
        commu_e_folder,
        COMMU_DATA_PATH[COMMU_CATEGORY_KEY[chara_commu['communicationCategory']]],
        chara_commu['communicationId'],
      )
    ensure
      sleep 8.0 if can_skip && $!.nil?
    end
    
    puts "(#{chara_data['id']}) checking unlisted commus..."
    [].tap do |unlisted_commus|
      # Promises
      [
        [1, true],
        [2, true],
        [3, true],
        [9, false],
      ].each do |(promise_place, promise_failguard)|
        commu_k = sprintf("%d%03d%03d%03d%d", 2, chara_data['id'], 1, 1, promise_place)
        unlisted_commus << [
          'common', 'produce_communications_promises',
          commu_k,
          "約束 %s" % [{1=>'Vo',2=>'Da',3=>'Vi',9=>'休む'}[promise_place]]
        ]
        promise_endings = [1, 2]
        promise_endings << 3 if promise_failguard
        promise_endings.sort!
        promise_endings.each do |promise_after|
          unlisted_commus << [
            'common', 'produce_communication_promise_results',
            "#{commu_k}#{promise_after}",
            "約束 %s" % [{1=>'Vo',2=>'Da',3=>'Vi',9=>'休む'}[promise_place]]
          ]
        end
      end
      # Halloween
      [
        ['halloween2019'],
        [16],
        [25],
      ].each_with_index do |(v), i|
        case v
        when 'halloween2019'
          1.upto(2) do |j|
            commu_k = sprintf("%s_%03d%d", v, chara_data['id'], j)
            unlisted_commus << [
              'joke', 'mypage_communications',
              commu_k,
              "Halloween #{2019 + i} (#{chara_data['firstName']}) #{(j == 1 ? :C : :X)}"
            ]
          end
        when Integer
          commu_k = sprintf("%2d%02d%03d%02d", 49, 1, v, chara_data['id'])
          unlisted_commus << [
            'joke', 'mypage_communications',
            commu_k,
            "Halloween #{2019 + i} (#{chara_data['firstName']})"
          ]
        end
      end
    end.each do |(commu_type, commu_group, commu_id, commu_title)|
      commu_g_folder = File.join(chara_folder, commu_type)
      commu_e_folder = File.join(commu_g_folder, commu_id)
      create_if_not commu_g_folder
      create_if_not commu_e_folder
      can_skip = false
      commu_file = File.join(commu_e_folder, 'scenario.json')
      mapping_names[commu_e_folder] = commu_title
      can_skip |= process_commu(
        commu_e_folder,
        commu_group,
        commu_id,
      )
    end
    
    puts "(#{chara_data['id']}) checking P-cards..."
    extended_card_data['idol_data'].each do |card_data|
      next if card_data['characterId'].to_i != TARGET_CHARA_ID
      %w(produceIdolEvents produceAfterEvents).each do |commu_k|
        card_data[commu_k]&.each do |card_commu|
          case commu_k
          when 'produceAfterEvents'; card_commu['category'] ||= 'after_event'
          end
          commu_g_folder = File.join(chara_folder, card_commu['category'])
          commu_e_folder = File.join(commu_g_folder, card_commu['id'])
          create_if_not commu_g_folder
          create_if_not commu_e_folder
          can_skip = false
          commu_file = File.join(commu_e_folder, 'scenario.json')
          mapping_names[commu_e_folder] = card_commu['title']
          can_skip |= process_commu(
            commu_e_folder,
            COMMU_DATA_PATH[COMMU_CATEGORY_KEY[card_commu['category']]],
            card_commu['id'],
          )
        ensure
          sleep 8.0 if can_skip && $!.nil?
        end
      end
      
      if card_data['rarity'] >= 4 && %w(1 2 3).include?(card_data['idolArrivalTypeId']) then
        card_folder = File.join(chara_folder, 'gasha')
        create_if_not card_folder
        gasha_file = File.join(card_folder, card_data['id'] + '.m4a')
        download_if_not gasha_file,
          encode_link(card_voice_link(card_data['id'], 'gasha'))
      end
    end
  
    puts "(#{chara_data['id']}) checking home conversation..."
    [].tap do |mypage_duet_list|
      unit_ids = UNIT_MEMBERS.flatten - [chara_data['id'].to_i]
      unit_ids.product([chara_data['id'].to_i]).each do |(chara_id_1, chara_id_2)|
        [false, true].each do |need_flip|
          current_pair = [chara_id_1, chara_id_2]
          current_pair.reverse! if need_flip
          
          current_pair.each_with_index do |c_chara_id, c_i|
            next if c_chara_id != chara_data['id'].to_i
            mypage_duet_list << [
              [*current_pair, 1],
              character_voice_link(
                c_chara_id,
                sprintf('mypage_talking_duo_%03d%03d%03d%03d0', *current_pair, 1,  c_i.succ)
              )
            ]
          end
        end
      end
    end.each do |duet_voice|
      duet_folder = File.join(chara_folder, 'myPageConversation', sprintf("%03d%03d%03d", *duet_voice[0]))
      create_if_not duet_folder
      duet_file = File.join(duet_folder, File.basename(duet_voice[1]))
      puts "  Downloading #{duet_voice[1]}" unless File.exists?(duet_file)
      download_if_not duet_file,
        encode_link(duet_voice[1])
    end
  end
  
  puts "Checking all S-card commus..."
  extended_card_data['support_idol'].each do |card_data|
    next if card_data.nil?
    next if card_data['character'].nil?
    # Comment this line to fetch all idol S-card commus.
    next if card_data['character']['unitId']&.to_i != TARGET_UNIT_ID
    chara_folder = File.join('characters', sprintf("%03d", card_data['characterId']))
    create_if_not chara_folder
    card_data['produceSupportIdolEvents'].each do |card_commu|
      commu_g_folder = File.join(chara_folder, card_commu['category'])
      commu_e_folder = File.join(commu_g_folder, card_commu['id'])
      create_if_not commu_g_folder
      create_if_not commu_e_folder
      can_skip = false
      commu_file = File.join(commu_e_folder, 'scenario.json')
      mapping_names[commu_e_folder] = card_commu['title']
      can_skip |= process_commu(
        commu_e_folder,
        COMMU_DATA_PATH[COMMU_CATEGORY_KEY[card_commu['category']]],
        card_commu['id'],
      )
    ensure
      sleep 8.0 if can_skip && $!.nil?
    end
  end
  
  chara_list.clear
  extended_card_data.clear
  
  puts "Checking bus commus..."
  create_if_not 'business'
  1.upto(5) do |unit_id|
    bus_comm_id = sprintf("%02d%02d%04d", 99, unit_id, 1)
    bus_comm_f = File.join('business', bus_comm_id)
    create_if_not bus_comm_f
    process_commu(
      bus_comm_f,
      'business_unit_communication',
      bus_comm_id
    )
  end
  
  File.open('data/mapping.csv', 'w') do |f|
    mapping_names.each do |k, v|
      p v if v.include?(',')
      f.write sprintf("%s|%s\n", k, v.gsub(/[|\t]/,' '))
    end
  end
end