require 'time'
require 'aws-sdk'
require 'logger'

$logger = Logger.new($stdout)

$logger.progname = File.basename(__FILE__)
$logger.formatter = proc do |severity, datetime, progname, msg|
  %Q|{"severity": "#{severity}", "datetime": "#{datetime.to_s}", "progname": "#{progname}", "message": "#{msg}"}\n|
end

$dynamo_db

NEW_YEAR_HOLIDAY = ['01-01', '01-02', '01-03']
NON_BURNABLE_COLLECTION_WEEK = [2, 4]
DAYS = ["日", "月", "火", "水", "木", "金", "土"]


### get garbage day modules
def non_burnable_day_today?(today)
    if !(today.tuesday?)
        $logger.error('invalid argument. today is not tuesday.')
        return false
    end

    tuesday_cnt = 0
    date_cnt = Time.parse("#{today.year}-#{today.month}-01") # beginning of month
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
    
def what_garbage_day?(today)
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
        if non_burnable_day_today?(today) then
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



### dynamo db modules
def register_schedule(date, garbageType, dynamo_db)
    item = {
        "date" => date.strftime("%Y-%m-%d"),
        "dayOfWeek" => DAYS[date.wday],
        "garbageType" => garbageType,
        "ttl" => date.to_i
    }      
    begin
        resp = dynamo_db.put_item({
            item: item, 
            table_name: ENV['DYNAMO_DB_TABLE_NAME'], 
        })
    rescue => error
        $logger.error("dynamo db put item exception. (detail:#{error})")
    end
end

def get_schedule(date, dynamo_db)
    begin 
        resp = dynamo_db.get_item(
            table_name: ENV['DYNAMO_DB_TABLE_NAME'],
            key: {
                date: date.strftime("%Y-%m-%d")
            }
        )
    rescue => error
        $logger.error("dynamo db get item exception. (detail:#{error})")
    end
        
    return resp.item
end



### line api modules
def push_message(text, endpoint, token)
    result = false

    uri = URI.parse(endpoint)
    http = Net::HTTP.new(uri.host, uri.port)
    
    params = {
        messages: [{
            type: 'text',
            text: text
        }]
    }
    headers = {
        "Content-Type" => "application/json", 
        "Authorization" => "Bearer " + token
    }

    begin 
        resp = http.post(uri.path, params.to_json, headers)
    rescue => error
        $logger.error("line push exception. (detail:#{error})")
        return result
    end

    if resp.code != "200"
        $logger.error("line push failed. (resp code:#{resp.code} body:#{resp.body})")
        return result
    end

    result = true
    return result
end

def notify_error(endpoint)
    result = false

    uri = URI.parse(endpoint)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    params = {
        text: 'error occured'
    }
    headers = {
        "Content-Type" => "application/json", 
    }
    

    begin 
        resp = http.post(uri.path, params.to_json, headers)
    rescue => error
        $logger.error("notify error exception. (detail:#{error})")
        return result
    end

    if resp.code != "200"
        $logger.error("notify error failed. (resp code:#{resp.code} body:#{resp.body})")
        return result
    end

    result = true
    return result
end


def main(today, dynamo_db, ine_api_url,line_token, slack_api_url)
    next_week = today + (60*60*24*7)
    item = get_schedule(today, dynamo_db)
    if item.nil? then
        $logger.info("item is not registered. put item.")
        date_cnt = today
        while date_cnt < next_week do
            garbageType = what_garbage_day?(date_cnt) 
            register_schedule(date_cnt, garbageType, dynamo_db)
            date_cnt += (60*60*24)
        end
    end

    weekly_schedule_list = []
    while today < next_week do
        weekly_schedule_list.push(get_schedule(today, $dynamo_db) )
        today += (60*60*24)
    end

    text = "☆今週のごみ収集のお知らせ☆ \n"
    for i in weekly_schedule_list do
        date = i['date'].gsub!("-","/")[5...10]
        text.concat("#{date}(#{i['dayOfWeek']}):  #{i['garbageType']}  \n")
    end
    text.concat("\n")
    text.concat("■ゴミの分別方法はこちら↓  \n")
    text.concat("https://www.city.ota.tokyo.jp/seikatsu/gomi/shigentogomi/katei-shigen-gomi_pamphlet.files/29wayaku.pdf  \n")

    result = push_message(text, ine_api_url, line_token)
    if result == false then
        notify_error(slack_api_url)
    end

    $logger.info("this process was successfull.")
end


### lambda handler
def lambda_handler(event:, context:)
    today = Time.now + (60*60*9) 
    $dynamo_db = Aws::DynamoDB::Client.new()
    main(today, $dynamo_db, ENV['LINE_API_URL'], ENV['LINE_TOKEN'], ENV['SLACK_API_URL'])
end