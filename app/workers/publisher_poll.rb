require 'app/services/connection_builder'
require 'app/services/publisher_update'

module Citygram::Workers
  class PublisherPoll
    include Sidekiq::Worker
    sidekiq_options retry: 5

    MAX_PAGE_NUMBER = 10
    NEXT_PAGE_HEADER = 'Next-Page'.freeze

    def perform(publisher_id, url, page_number = 1)
      # fetch publisher record or raise
      publisher = Publisher.first!(id: publisher_id)

      # prepare a connection for the given url
      connection = Citygram::Services::ConnectionBuilder.json("request.publisher.#{publisher.id}", url: url)

      # execute the request or raise
      response = connection.get

      # compare database events to api events and remove events that are no longer in the api
      api_data = response.body["features"].map{ |feature| feature["id"] }
      puts "API Data Length: " + api_data.length.to_s
      app_data = Citygram::Models::Event.where(:publisher_id => publisher_id).map{ |event| event.feature_id.to_s }
      puts "Database Data Length: " + app_data.length.to_s
      diff = app_data - api_data
      puts diff
      puts "Removing " + diff.length.to_s + " old events"
      remove_all_events

      # save any new events
      feature_collection = response.body
      new_events = Citygram::Services::PublisherUpdate.call(feature_collection.fetch('features'), publisher)

      # OPTIONAL PAGINATION:
      #
      # iff successful to this point, and a next page is given
      # queue up a job to retrieve the next page
      #
      next_page = response.headers[NEXT_PAGE_HEADER]
      if new_events.any? && valid_next_page?(next_page, url) && page_number < MAX_PAGE_NUMBER
        self.class.perform_async(publisher_id, next_page, page_number + 1)
      end
    end

    private

    def valid_next_page?(next_page, current_page)
      return false unless next_page.present?

      next_page = URI.parse(next_page)
      current_page = URI.parse(current_page)

      next_page.host == current_page.host
    end

    def remove_all_events
      Citygram::Models::Event.all.destroy_all
    end
    def remove_old_events(event_ids)
      event_ids.each do |id|
        Citygram::Models::Event.where(:feature_id => id).destroy
      end
    end
  end
end
