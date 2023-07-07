require_relative '../lib/spec_helper.rb'
require_relative '../lib/function.rb'
require_relative 'get_bot_monitoring_information.rb'

ENV['ENVIRONMENT'] = 'development'
ENV['AWS_RESOURCE_NAME'] = 'Slack Bot'

WebMock.allow_net_connect!

RSpec.describe GetBotMonitoringInformation do
  describe '.execute' do
    it 'gets metric statistics' do
      result = GetBotMonitoringInformation.new.execute({})

      puts "Result:\n#{result.ai}"
    end
  end
end