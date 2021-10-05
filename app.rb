require 'sinatra'
require 'bandwidth'

include Bandwidth
include Bandwidth::Messaging

BW_USERNAME = ENV.fetch("BW_USERNAME")
BW_PASSWORD = ENV.fetch("BW_PASSWORD")
BW_NUMBER = ENV.fetch("BW_NUMBER")
BW_MESSAGING_APPLICATION_ID = ENV.fetch("BW_MESSAGING_APPLICATION_ID")
BW_ACCOUNT_ID = ENV.fetch("BW_ACCOUNT_ID")
LOCAL_PORT = ENV.fetch("LOCAL_PORT")

set :port, LOCAL_PORT

bandwidth_client = Bandwidth::Client.new(
    messaging_basic_auth_user_name: BW_USERNAME,
    messaging_basic_auth_password: BW_PASSWORD
)
messaging_client = bandwidth_client.messaging_client.client

account_id = BW_ACCOUNT_ID

post '/callbacks/outbound/messaging' do
    #Make a post request to this url to send outbound MMS with media

    body = MessageRequest.new
    body.application_id = account_id
    body.to = [data["to"]]
    body.from = BW_NUMBER
    body.text = data["text"]
    body.media = ["https://cdn2.thecatapi.com/images/MTY3ODIyMQ.jpg"]

    messaging_client.create_message(account_id, body)
    return ''
end

post '/callbacks/inbound/messaging' do
    #This URL handles inbound messages.
    #If the inbound message contains media, that media is downloaded
    data = JSON.parse(request.body.read)
    if data[0]["type"] == "message-received"
        puts "Message received"
        puts "To: " + data[0]["message"]["to"][0] + "\nFrom: " + data[0]["message"]["from"] + "\nText: " + data[0]["message"]["text"]
        if data[0]["message"].key?("media")
            data[0]["message"]["media"].each do |media|
                media_id = media.split("/").last(3)
                downloaded_media = messaging_client.get_media(account_id, media_id).data
                puts downloaded_media
            end
        end
    else
        puts "Message type does not match endpoint. This endpoint is used for inbound messages only.\nOutbound message callbacks should be sent to /callbacks/outbound/messaging."
    end

    return ''
end
puts "test"
# post '/mediaManagement' do
#     #Make a POST request to this endpoint to upload a media file to Bandwidth, then download it
#     #and print its contents
#     media = "simple text string"
#     media_id = "bandwidth-sample-app"

#     messaging_client.upload_media(account_id, media_id, media.length.to_s, media, :content_type => "application/octet-stream", :cache_control => "no-cache")

#     downloaded_media = messaging_client.get_media(account_id, media_id).data
#     puts downloaded_media

#     return ''
# end
