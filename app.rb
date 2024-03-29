require 'sinatra'
require 'bandwidth-sdk'

begin
  BW_ACCOUNT_ID = ENV.fetch('BW_ACCOUNT_ID')
  BW_USERNAME = ENV.fetch('BW_USERNAME')
  BW_PASSWORD = ENV.fetch('BW_PASSWORD')
  BW_NUMBER = ENV.fetch('BW_NUMBER')
  BW_MESSAGING_APPLICATION_ID = ENV.fetch('BW_MESSAGING_APPLICATION_ID')
  LOCAL_PORT = ENV.fetch('LOCAL_PORT')
rescue StandardError
  puts 'Please set the environmental variables defined in the README'
  exit(-1)
end

set :port, LOCAL_PORT

Bandwidth.configure do |config| # Configure Basic Auth
  config.return_binary_data = true
  config.username = BW_USERNAME
  config.password = BW_PASSWORD
end

post '/sendMessage' do # Make a POST request to this URL to send a text message.
  data = JSON.parse(request.body.read)
  body = Bandwidth::MessageRequest.new(
    {
      application_id: BW_MESSAGING_APPLICATION_ID,
      from: BW_NUMBER,
      media: ['https://cdn2.thecatapi.com/images/MTY3ODIyMQ.jpg'],
      **data
    }
  )

  messaging_api_instance = Bandwidth::MessagesApi.new
  messaging_api_instance.create_message(BW_ACCOUNT_ID, body)
end

post '/callbacks/outbound/messaging/status' do # This URL handles outbound message status callbacks.
  data = JSON.parse(request.body.read)
  case data[0]['type']
  when 'message-sending'
    puts 'MMS message is sending.'
  when 'message-delivered'
    puts "Your message has been handed off to the Bandwidth's MMSC network, but has not been confirmed at the downstream carrier."
  when 'message-failed'
    puts 'For MMS and Group Messages, you will only receive this callback if you have enabled delivery receipts on MMS.'
  else
    puts 'Message type does not match endpoint. This endpoint is used for message status callbacks only.'
  end
end

post '/callbacks/inbound/messaging' do # This URL handles inbound message callbacks.
  data = JSON.parse(request.body.read)
  inbound_body = Bandwidth::InboundMessageCallback.build_from_hash(data[0])
  puts inbound_body.description
  if inbound_body.type == 'message-received'
    puts "To: #{inbound_body.message.to[0]}\nFrom: #{inbound_body.message.from}\nText: #{inbound_body.message.text}"

    media_api_instance = Bandwidth::MediaApi.new
    inbound_body.message.media&.each do |media|
      media_id = media.partition('media/').last # media id used for GET media
      media_name = media_id.rpartition('/').last # used for naming the downloaded image file
      next if media_name.include? '.xml'

      filename = "./#{media_name}"
      downloaded_media = media_api_instance.get_media(BW_ACCOUNT_ID, media_id)
      File.open(filename, 'wb') { |f| f.write(downloaded_media) }
    end
  else
    puts 'Message type does not match endpoint. This endpoint is used for inbound messages only.'
    puts 'Outbound message callbacks should be sent to /callbacks/outbound/messaging.'
  end
end
