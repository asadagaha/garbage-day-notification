require 'time'
require 'aws-sdk'
require 'logger'

$logger = Logger.new($stdout)


NEW_YEAR_HOLIDAY = ['01-01', '01-02', '01-03']
NON_BURNABLE_COLLECTION_WEEK = [2, 4]
DAYS = ["日", "月", "火", "水", "木", "金", "土"]
REQUEST_URL = "https://api.line.me/v2/bot/message/broadcast"
LINE_TOKEN = ENV['LINE_TOKEN']
DYNAMO_DB_TABLE_NAME = ENV['DYNAMO_DB_TABLE_NAME']


def is_it_non_burnable_day_today(today)
    if !(today.tuesday?)
        $logger.error('invalid argument. today is not tuesday.')
        return false
    end

    tuesday_cnt = 0
    date_cnt = Time.parse("#{today.year}-#{today.month}/01") # beginning of month
    while date_cnt <= today do
          if date_cnt.tuesday? then
              tuesday_cnt += 1
          end
          date_cnt+= (60*60*24)
    end
    if NON_BURNABLE_COLLECTION_WEEK.include?(tuesday_cnt) then
        result = true
    else
        result = false
    end
    
    return result
end
    
def what_garbage_day_is_today(today)
    garbageType = ""
    if NEW_YEAR_HOLIDAY.include?(today.strftime("%m-%d")) then
        garbageType = "年末年始のため回収なし"
        return garbageType
    end
    
    dayOfWeek = DAYS[today.wday]
    case dayOfWeek
    when "月" then
      garbageType = "燃えるごみ"
    when "火" then
        if is_it_non_burnable_day_today(today) then
            garbageType = '不燃ごみ'
        else
            garbageType = '-'
        end
    when "水" then
        garbageType = "資源ごみ"
    when "木" then
        garbageType = "燃えるごみ"
    else
        garbageType = "-"
    end

    return garbageType
end


def register_garbage_day_schedule(today, dynamo_db)

    date_cnt = today
    end_cnt = today + (60*60*24*30)
    while date_cnt <= end_cnt do
        garbageType = what_garbage_day_is_today(date_cnt)
        ttl = (date_cnt + (60*60*24*2)).to_i

        item = {
            "date" => date_cnt.strftime("%Y-%m-%d"),
            "dayOfWeek" => DAYS[date_cnt.wday],
            "garbageType" => garbageType,
            "ttl" => ttl
        }
        
        begin
            resp = dynamo_db.put_item({
                item: item, 
                table_name: DYNAMO_DB_TABLE_NAME, 
            })
        rescue => error
            $logger.error("dynamo db put item failed. (detail:#{error})")
        end
        date_cnt += (60*60*24)
    end
end

def get_weekly_schedule(today, dynamo_db)
    weekly_schedule_list = []
    
    date_cnt = today
    end_cnt = today + (60*60*24*6)
    while date_cnt <= end_cnt do
        
        begin 
            resp = dynamo_db.get_item(
                table_name: DYNAMO_DB_TABLE_NAME,
                key: {
                    date: date_cnt.strftime("%Y-%m-%d")
                }
            )
        rescue => error
            $logger.error("dynamo db get item failed. (detail:#{error})")
        end
        
        item = resp.item
        weekly_schedule_list.push(item)

        date_cnt += (60*60*24)
    end
    
    return weekly_schedule_list
end


def push_message(text)
    uri = URI.parse(REQUEST_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    
    params = {
        messages: [{
            type: 'text',
            text: text
        }]
    }
    headers = {
        "Content-Type" => "application/json", 
        "Authorization" => "Bearer " + LINE_TOKEN
    }
    
    response = http.post(uri.path, params.to_json, headers)
    if response.code != "200"
        $logger.error("line push failed. (response code:#{response.code} body:#{response.body})")
    end
end


def lambda_handler(event:, context:)
    dynamo_db = Aws::DynamoDB::Client.new()
    today = Time.now + (60*60*9)
    
    register_garbage_day_schedule(today, dynamo_db)
    
    weekly_schedule_list = get_weekly_schedule(today, dynamo_db) 
    
    
    text = "☆今週のごみ収集のお知らせ☆ \n"
    for i in weekly_schedule_list do
        date = i['date'].gsub!("-","/")[5...10]
        text.concat("#{date}(#{i['dayOfWeek']}):  #{i['garbageType']}  \n")
    end
    text.concat("■ゴミの分別方法はこちら↓  \n")
    text.concat("https://www.city.ota.tokyo.jp/seikatsu/gomi/shigentogomi/katei-shigen-gomi_pamphlet.files/29wayaku.pdf  \n")
    push_message(text)

end


