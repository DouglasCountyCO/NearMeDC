require 'spec_helper'

describe Citygram::Workers::PublisherPoll do
  subject { Citygram::Workers::PublisherPoll.new }
  let(:publisher) { create(:publisher) }
  let(:features) { JSON.parse(body)['features'] }
  let(:body) { fixture('cmpd-traffic-incidents.geojson') }
  let(:new_events) { double('new events', any?: true) }

  describe '#perform' do
    before do
      stub_request(:get, publisher.endpoint).
        with(headers: {'Accept'=>'application/json'}).
        to_return(status: 200, body: body)
    end

    it 'retrieves the latest events from the publishers endpoint' do
      subject.perform(publisher.id, publisher.endpoint)
      expect(a_request(:get, publisher.endpoint)).to have_been_made
    end
  end

  it 'limits the number of retries' do
    retries = Citygram::Workers::PublisherPoll.sidekiq_options_hash["retry"]
    expect(retries).to eq 5
  end
end