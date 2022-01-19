require 'sinatra'
require 'openapi_ruby_sdk_binary' # replace with new gem name************

include RubySdk # replace with new module name**************

BW_ACCOUNT_ID = ENV.fetch("BW_ACCOUNT_ID")
BW_USERNAME = ENV.fetch("BW_USERNAME")
BW_PASSWORD = ENV.fetch("BW_PASSWORD")
BW_NUMBER = ENV.fetch("BW_NUMBER")
BW_MESSAGING_APPLICATION_ID = ENV.fetch("BW_MESSAGING_APPLICATION_ID")
LOCAL_PORT = ENV.fetch("LOCAL_PORT")

set :port, LOCAL_PORT

RubySdk.configure do |config|   # replace with new module name************   # Configure HTTP basic authorization: httpBasic
    config.username = BW_USERNAME
    config.password = BW_PASSWORD
end

$api_instance_msg = RubySdk::MessagesApi.new()  # replace with new module name************
$api_instance_media = RubySdk::MediaApi.new()   # replace with new module name************

post '/sendMessage' do  # Make a POST request to this URL to send a text message.
    data = JSON.parse(request.body.read)
    body = MessageRequest.new
    body.application_id = BW_MESSAGING_APPLICATION_ID
    body.to = [data["to"]]
    body.from = BW_NUMBER
    body.text = data["text"]
    body.media = ["https://cdn2.thecatapi.com/images/MTY3ODIyMQ.jpg"]

    response = $api_instance_msg.create_message(BW_ACCOUNT_ID, body)

    return ''
end

post '/callbacks/outbound/messaging/status' do  # This URL handles outbound message status callbacks.
    data = JSON.parse(request.body.read)
    case data[0]["type"] 
        when "message-sending"
            puts "message-sending type is only for MMS."
        when "message-delivered"
            puts "Your message has been handed off to the Bandwidth's MMSC network, but has not been confirmed at the downstream carrier."
        when "message-failed"
            puts "For MMS and Group Messages, you will only receive this callback if you have enabled delivery receipts on MMS."
        else
            puts "Message type does not match endpoint. This endpoint is used for message status callbacks only."
        end
    return ''
end

post '/callbacks/inbound/messaging' do  # This URL handles inbound message callbacks.
    data = JSON.parse(request.body.read, :symbolize_names => true)
    inbound_body = BandwidthCallbackMessage.new.build_from_hash(data[0])
    puts inbound_body.description
    if inbound_body.type == "message-received"
        puts "To: " + inbound_body.message.to[0] + "\nFrom: " + inbound_body.message.from + "\nText: " + inbound_body.message.text
        if !inbound_body.message.media.nil?
            inbound_body.message.media.each do |media|
                media_id = media.partition("media/").last   # media id used for GET media
                media_name = media_id.rpartition("/").last  # used for naming the downloaded image file
                unless media_name.include? ".xml"
                    filename = "./" + media_name
                    downloaded_media = $api_instance_media.get_media(BW_ACCOUNT_ID, media_id, debug_return_type: 'Binary')
                    File.open(filename, 'wb') { |f| f.write(downloaded_media) }                  
                end
                
            end
        end
    else
        puts "Message type does not match endpoint. This endpoint is used for inbound messages only.\nOutbound message callbacks should be sent to /callbacks/outbound/messaging."
    end

    return ''
end
