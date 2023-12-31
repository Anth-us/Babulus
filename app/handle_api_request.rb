require 'json'
require 'aws-sdk-sqs'

$LOAD_PATH.unshift('./lib/')
require 'babulus'

def handle_aws_lambda_event_for_api_request(event:, context:)
  $logger.debug("Received Slack API event from API Gateway:\n#{JSON.pretty_generate(event)}")
  $logger.debug("Parsed body:\n#{JSON.pretty_generate(JSON.parse(event['body']))}")

  # We need to examine the Slack message to see if it's a URL verification
  # request or a message event.  The Slack event is passed as a JSON string
  # in the body of the Lambda event.
  slack_event_handler = Babulus::SlackEventsAPIHandler.new(event['body'])

  # We must respond immediately, either way.  But, when it's a URL verification
  # request, we must respond with the challenge value.  And, when it's a message
  # event, we must respond immediately with a 200 OK, and then process the
  # message asynchronously.
  if slack_event_handler.event_type == 'url_verification'
    $logger.info("Responding to URL verification request with challenge: #{slack_event_handler.url_confirmation}")
    return {
      statusCode: 200,
      body: slack_event_handler.dispatch
    }
  end

  unless slack_event_handler.event_needs_processing?
    $logger.info("Event does not need processing.  Responding with 200 OK.")
    return {
      statusCode: 200,
      body: 'Event does not need processing.'
    }
  end

  $logger.info("Enqueing SQS message for processing and responding with 200 OK.")

  # When it's a message event, we must post the message to the SQS queue for
  # asynchronous processing.
  sqs = Aws::SQS::Client.new(region: ENV['AWS_REGION'] || 'us-east-1')
  sqs.send_message(
    queue_url: ENV['SQS_QUEUE_URL'],
    message_body: event['body'],
    message_group_id: JSON.parse(event['body'])['event']['ts']
  )

  # Respond to the Slack API immediately with a 200 OK, once the message
  # is processing.
  {
    statusCode: 200,
    body: 'Message received.'
  }
end
