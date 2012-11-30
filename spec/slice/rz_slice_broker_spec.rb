require "project_razor"
require "rspec"
require "net/http"
require "json"

describe "ProjectRazor::Slice::Broker" do

  describe ".RESTful Interface" do

    before(:each) do
      @data = ProjectRazor::Data.instance
      @data.check_init
      @config = @data.config
      @data.delete_all_objects(:broker)
    end

    after(:each) do
      @data.delete_all_objects(:broker)
    end

    def razor_uri(path)
      URI("http://127.0.0.1:#{@config.api_port}/#{path.sub(%r{^/}, '')}")
    end

    def create_broker_via_rest(hash)
      uri = razor_uri("/razor/api/broker/add")
      Net::HTTP.post_form(uri, 'json_hash' => JSON.generate(hash))
    end

    let(:json_hash) do
      {
        "plugin"      => "puppet",
        "name"        => "puppet_test",
        "description" => "puppet_test_description",
        "req_metadata_hash" => {
          "server"          => "puppet.example.com",
          "broker_version"  => "2.0.9"
        }
      }
    end

    [ "/razor/api/broker/plugins", "/razor/api/broker/get/plugins" ].each do |path|
      it "GET #{path} lists all broker plugins" do
        res = Net::HTTP.get(razor_uri(path))
        res_hash = JSON.parse(res)
        brokers_plugins = res_hash['response']
        brokers_plugins.count.should > 0
        puppet_flag = false # We will just check for the puppet broker plugin
        brokers_plugins.each {|t| puppet_flag = true if t["@plugin"] == "puppet"}
        puppet_flag.should == true
      end
    end

    context "with no broker targets" do

      it "should be able to create broker target from REST using GET" do
        pending "Not a published API action"
        uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker/add?plugin=puppet&name=RSPECPuppetGET&description=RSPECSystemInstanceGET&servers=rspecpuppet.example.org"
        res = Net::HTTP.get(uri)
        res_hash = JSON.parse(res)
        res_hash['result'].should == "Created"
        broker_response_array = res_hash['response']
        $broker_uuid_get = broker_response_array.first['@uuid']
        $broker_uuid_get.should_not == nil
      end

      it "POST /razor/api/broker/add creates a broker target" do
        uri = razor_uri("/razor/api/broker/add")
        res = Net::HTTP.post_form(uri, 'json_hash' => JSON.generate(json_hash))
        res_hash = JSON.parse(res.body)
        res_hash['result'].should == "Created"
        broker = res_hash['response'].first
        $broker_uuid_post = broker['@uuid']
        $broker_uuid_post.should_not == nil
        broker['@name'].should eq("puppet_test")
        broker['@user_description'].should eq("puppet_test_description")
        broker['@server'].should eq("puppet.example.com")
        broker['@broker_version'].should eq("2.0.9")
      end
    end

    context "with one broker target" do

      before do
        res = create_broker_via_rest(json_hash)
        @broker = JSON.parse(res.body)['response'].first
      end

      [ "/razor/api/broker", "/razor/api/broker/get" ].each do |path|
        it "GET #{path} lists all brokers targets" do
          res = Net::HTTP.get(razor_uri(path))
          res_hash = JSON.parse(res)
          brokers_plugins = res_hash['response']
          brokers_plugins.count.should == 1
          brokers_plugins.first['@uuid'].should eq(@broker['@uuid'])
        end
      end

      [ "/razor/api/broker", "/razor/api/broker/get" ].each do |path|
        it "GET #{path}/<uuid> finds the specific broker target" do
          broker_uuid = @broker['@uuid']
          res = Net::HTTP.get(razor_uri("#{path}/#{broker_uuid}"))
          res_hash = JSON.parse(res)
          broker_response_array = res_hash['response']
          broker_response_array.count.should == 1
          broker_response_array.first['@uuid'].should == broker_uuid
        end

        it "GET #{path}?name=regex:<text> finds the broker target by attribute" do
          res = Net::HTTP.get(razor_uri("#{path}?name=regex:puppet"))
          res_hash = JSON.parse(res)
          res_hash['result'].should == "Ok"
          broker_response_array = res_hash['response']
          broker = broker_response_array.first
          broker['@uuid'].should == @broker['@uuid']
        end

        it "GET /#{path}?name=<full_text> finds the broker target by attribute" do
          res = Net::HTTP.get(razor_uri("#{path}?name=puppet_test"))
          res_hash = JSON.parse(res)
          res_hash['result'].should == "Ok"
          broker_response_array = res_hash['response']
          broker = broker_response_array.first
          broker['@uuid'].should == @broker['@uuid']
        end
      end

      it "GET /remove/api/broker/remove/<uuid> deletes specific broker target" do
        broker_uuid = @broker['@uuid']

        res = Net::HTTP.get(razor_uri("/razor/api/broker/remove/#{broker_uuid}"))
        res_hash = JSON.parse(res)
        res_hash['result'].should == "Removed"

        res = Net::HTTP.get(razor_uri("/razor/api/broker/#{broker_uuid}"))
        res_hash = JSON.parse(res)
        res_hash['errcode'].should_not == 0
      end

      it "DELETE /razor/api/broker/remove/all cannot delete all broker targets" do
        uri = razor_uri("/razor/api/broker/remove/all")
        http = Net::HTTP.start(uri.host, uri.port)
        res = http.send_request('DELETE', uri.request_uri)
        res.class.should == Net::HTTPMethodNotAllowed
        res_hash = JSON.parse(res.body)

        res = Net::HTTP.get(razor_uri("/razor/api/broker"))
        res_hash = JSON.parse(res)
        brokers_get = res_hash['response']
        brokers_get.count.should == 1
      end
    end
  end
end
