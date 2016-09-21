require 'app/services/connection_builder'
require 'app/services/publisher_update'
require 'pry'

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

      # Check to make sure the api endpoint is working before deleting any events.
      if response.status == 200

        # compare database events to api events and remove events that are no longer in the api
        puts ("Updating Publisher " + publisher_id.to_s + ": " + publisher.title).green
        api_data = response.body["features"].map{ |feature| feature["id"] }
        puts ("Publisher " + publisher_id.to_s + " number of API events: " + api_data.length.to_s).yellow
        app_data = Citygram::Models::Event.where(:publisher_id => publisher_id).map{ |event| event.feature_id.to_s }
        puts ("Publisher " + publisher_id.to_s + " number of database events: " + app_data.length.to_s).yellow
        diff = app_data - api_data
        puts ("Publisher " + publisher_id.to_s + " Removing " + diff.length.to_s + " old events").red
        remove_old_events(diff, publisher_id)

        # save any new events
        feature_collection = response.body
        new_events = Citygram::Services::PublisherUpdate.call(feature_collection.fetch('features'), publisher)
        puts ("Publisher " + publisher_id.to_s + " Adding " + new_events.length.to_s + " new events").green
      end

      # OPTIONAL PAGINATION:
      #
      # iff successful to this point, and a next page is given
      # queue up a job to retrieve the next page
      #
      # next_page = response.headers[NEXT_PAGE_HEADER]
      # if new_events.any? && valid_next_page?(next_page, url) && page_number < MAX_PAGE_NUMBER
      #   self.class.perform_async(publisher_id, next_page, page_number + 1)
      # end
    end

    private

    def valid_next_page?(next_page, current_page)
      return false unless next_page.present?

      next_page = URI.parse(next_page)
      current_page = URI.parse(current_page)

      next_page.host == current_page.host
    end

    def remove_old_events(event_ids, publisher_id)
      event_ids.each do |id|
        Citygram::Models::Event.where(:feature_id => id, :publisher_id => publisher_id).delete
      end
    end
  end
end
