require 'json'
require 'logger'
require 'awesome_print'
require 'aws-sdk-sqs'
require_relative 'slack_events_api'

def lambda_handler(event:, context:)
  logger = Logger.new(STDOUT)
  logger.info("Received event from Lambda: #{event.ai}")

  # We need to examine the Slack message to see if it's a URL verification
  # request or a message event.  The Slack event is passed as a JSON string
  # in the body of the Lambda event.
  slack_event_handler = SlackEventsAPIHandler.new(event['body'])

  # We must respond immediately, either way.  But, when it's a URL verification
  # request, we must respond with the challenge value.  And, when it's a message
  # event, we must respond immediately with a 200 OK, and then process the
  # message asynchronously.
  if slack_event_handler.event_type == 'url_verification'
    logger.info("Responding to URL verification request with challenge: #{slack_event_handler.url_confirmation}")
    return {
      statusCode: 200,
      body: slack_event_handler.dispatch
    }
  end

  logger.info("Enqueing SQS message for processing and responding with 200 OK.")

  # When it's a message event, we must post the message to the SQS queue for
  # asynchronous processing.
  sqs = Aws::SQS::Client.new(region: ENV['AWS_REGION'] || 'us-east-1')
  sqs.send_message(
    queue_url: ENV['SQS_QUEUE_URL'],
    message_body: event['body']
  )

  # Respond to the Slack API immediately with a 200 OK, once the message
  # is processing.
  {
    statusCode: 200,
    body: 'Message received.'
  }
end
