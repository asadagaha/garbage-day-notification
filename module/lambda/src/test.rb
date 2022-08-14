require 'test/unit'
require 'docker'
require 'webmock'
require 'net/https'
require './main'



$dynamo_db_container
$dynamo_db
WebMock.enable!
WebMock.allow_net_connect!

LINE_MOCK_URI = "http://www.push-test.com"
SLACK_MOCK_URI = "https://www.slack-test.com"

def setup_dynamo_db
    Docker.url = 'unix:///var/run/docker.sock'
    port = "8000"

    $dynamo_db_container = Docker::Container.create(
        "name" => 'dynamo_db',
        "Image" => 'amazon/dynamodb-local',
        "Cmd" => ["-jar", "DynamoDBLocal.jar", "-sharedDb"],
        "PortBindings" => {
            "#{port}/tcp" => [{
                "HostPort" => "#{port}"
            }],
        }
    )
    $dynamo_db_container.start

    $dynamo_db = Aws::DynamoDB::Client.new(
        endpoint: "http://localhost:#{port}", 
        region: 'ap-northeast-1'    
    )
    sleep 2
end

def shutdown_dynamo_db
    sleep 2
    $dynamo_db_container.stop
    $dynamo_db_container.remove    
end

def setup_line_client
    WebMock.stub_request(:post, LINE_MOCK_URI).to_return(
        body: {"body":"成功時に帰ってくるbody"}.to_json,
        status: 200,
        headers: { 
            "Content-Type" => "application/json", 
            "Authorization" => "Bearer " + ENV['LINE_TOKEN']
        }
    )
end

def setup_slack_client
    WebMock.stub_request(:post, SLACK_MOCK_URI).to_return(
        body: {"body":"成功時に帰ってくるbody"}.to_json,
        status: 200,
        headers: { 
            "Content-Type" => "application/json", 
        }
    )
end



def create_table
    resp = $dynamo_db.create_table({
        attribute_definitions: [{
            attribute_name: "date",
            attribute_type: "S"
        }],
        table_name: ENV['DYNAMO_DB_TABLE_NAME'] ,
        key_schema: [{
            attribute_name: "date",
            key_type: "HASH",
        }],
        billing_mode: "PAY_PER_REQUEST"
    })
    resp = $dynamo_db.update_time_to_live({
        table_name: ENV['DYNAMO_DB_TABLE_NAME'] ,
        time_to_live_specification: { 
            enabled: true,
            attribute_name: "ttl",
        },
    })
end

def delete_table
    resp = $dynamo_db.delete_table({
        table_name: ENV['DYNAMO_DB_TABLE_NAME'] , 
    })
end


class TestIsItNonBurnableDayToday < Test::Unit::TestCase
    def test_second_tuesday
        today = Time.parse("2022/08/09") # sencond tuesday
        assert_equal(true, non_burnable_day_today?(today))
    end
    def test_fourth_tuesday
        today = Time.parse("2022/08/23") # fourth tuesday
        assert_equal(true, non_burnable_day_today?(today))
    end
    def test_not_tuesday
        today = Time.parse("2022/08/01") # monday
        assert_equal(false, non_burnable_day_today?(today))
    end
    def test_not_garbage_tuesday
        today = Time.parse("2022/08/02") # first tuesday
        assert_equal(false, non_burnable_day_today?(today))
    end
end

class TestWhatGarbageDayIsToday < Test::Unit::TestCase
    def test_new_year_holiday
        today = Time.parse("2022/01/01") # new year holiday
        assert_equal("年末年始のため回収なし", what_garbage_day?(today))
    end
    def test_monday
        today = Time.parse("2022/08/01") # monday
        assert_equal("燃えるごみ", what_garbage_day?(today))
    end
    def test_first_tuesday
        today = Time.parse("2022/08/02") # first tuesday
        assert_equal("-", what_garbage_day?(today))
    end
    def test_second_tuesday
        today = Time.parse("2022/08/09") # second tuesday
        assert_equal("不燃ごみ", what_garbage_day?(today))
    end
    def test_wednesday
        today = Time.parse("2022/08/03") # wednesday
        assert_equal("資源ごみ", what_garbage_day?(today))
    end
    def test_thursday
        today = Time.parse("2022/08/04") # thursday
        assert_equal("燃えるごみ", what_garbage_day?(today))
    end
    def test_non_garbage_day
        today = Time.parse("2022/08/05") # not garbage day(friday)
        assert_equal("-", what_garbage_day?(today))
    end
end

class TestRegisterSchedule < Test::Unit::TestCase
    
    class << self
        def startup
            setup_dynamo_db
        end
    
        def shutdown
            shutdown_dynamo_db
        end
    end

    def setup
        create_table
    end

    def teardown
        delete_table
    end


    def test_register_success
        date_str = "2022-08-01"
        date = Time.parse(date_str)
        garbageType = "燃えるごみ"
        register_schedule(date, garbageType, $dynamo_db)
        result = $dynamo_db.scan(
            table_name: ENV['DYNAMO_DB_TABLE_NAME'] 
        )
        assert_equal(1, result.items.size)

        result = $dynamo_db.get_item({
            table_name: ENV['DYNAMO_DB_TABLE_NAME'] ,
            key: {
              "date" => date_str,
            },
        })
        item = result['item']

        assert_equal(date_str, item['date'])
        assert_equal("月", item['dayOfWeek'])
        assert_equal(garbageType, item['garbageType'])
        assert_equal(date.to_i, item['ttl'])
    end 
=begin
    def test_dynamo_db_down
        $dynamo_db_container.stop

        date = Time.parse("2022/08/01")
        garbageType = "燃えるごみ"
        register_schedule(date, garbageType, $dynamo_db)
        result = $dynamo_db.scan(
            table_name: DYNAMO_DB_TABLE_NAME
        )
        puts result

        $dynamo_db_container.start
    end        
=end

end

class TestGetSchedule < Test::Unit::TestCase
    class << self
        def startup
            setup_dynamo_db
        end
    
        def shutdown
            shutdown_dynamo_db
        end
    end

    def setup
        create_table
    end

    def teardown
        delete_table
    end

    def test_get_success
        date = Time.parse("2022-08-01")
        garbageType = "燃えるごみ"
        register_schedule(date, garbageType, $dynamo_db)
        item = {
            "date" => date.strftime("%Y-%m-%d"),
            "dayOfWeek" => DAYS[date.wday],
            "garbageType" => garbageType,
            "ttl" => date.to_i
        }
        assert_equal(item, get_schedule(date, $dynamo_db))
    end 
    
end

class TestPushMessage < Test::Unit::TestCase
    class << self
        def startup
            setup_line_client
        end
    end

    def test_push_success
        text = "hello"
        endpoint = "#{LINE_MOCK_URI}/"
        line_token = "dummy-token"
        result = push_message(text, endpoint, line_token)
        assert_equal(true, result)
    end
end

class TestErrorNotify < Test::Unit::TestCase
    class << self
        def startup
            setup_slack_client
        end
    end


    def test_error_notify
        setup_slack_client
        endpoint = "#{SLACK_MOCK_URI}/"
        result = notify_error(endpoint)
        assert_equal(true, result)
    end
    
end



class TestMain < Test::Unit::TestCase
    class << self
        def startup
            setup_dynamo_db
            setup_line_client
        end
    
        def shutdown
            shutdown_dynamo_db
        end
    end

    def setup
        create_table
    end

    def teardown
        delete_table
    end

    def test_not_registered_item
        today = Time.parse("2022-07-01")
        line_api_url = "#{LINE_MOCK_URI}/"
        slack_api_url = "#{SLACK_MOCK_URI}/"
        line_token = "dummy-token"

        assert_equal(true, main(today, $dynamo_db, line_api_url, line_token, slack_api_url))
    
        next_week = today + (60*60*24*7)
        date_cnt = today
        while date_cnt < next_week do
            item = get_schedule(date_cnt, $dynamo_db)
            assert_equal(date_cnt.strftime("%Y-%m-%d"), item['date'])
            date_cnt += (60*60*24)
        end
    end
    
end




