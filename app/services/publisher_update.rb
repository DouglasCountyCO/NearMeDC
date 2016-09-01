module Citygram
  module Services
    class PublisherUpdate < Struct.new(:features, :publisher)
      def self.call(features, publisher)
        new(features, publisher).call
      end

      def call
        queue_notifications
        return new_events
      end

      def queue_notifications
        sql = <<-SQL.dedent
          SELECT subscriptions.id AS subscription_id, events.id AS event_id
          FROM subscriptions INNER JOIN events
            ON ST_Intersects(subscriptions.geom, events.geom)
            AND subscriptions.publisher_id = events.publisher_id
            AND subscriptions.unsubscribed_at IS NULL
            AND channel <> 'email'
          WHERE events.id in ?
        SQL

        @new_events = new_events
        # Checks to see if there is any new/updated events, if there is send out notifications
        if @new_events && @new_events.length > 0
          events = @new_events.map { |event| { :id => event.id, :title => event.title} }
          puts "There are " + events.length.to_s + " events"
          events = events.uniq{|event| event[:title] }
          puts "There are " + events.length.to_s + " unique events"


          puts "Sending text message notifications for " + events.length.to_s + " events"
          dataset = Sequel::Model.db.dataset.with_sql(sql, events.map { |event| event[:id] })

          dataset.paged_each do |pair|
            # sends outs a text for each new event.
            Citygram::Workers::Notifier.perform_async(pair[:subscription_id], pair[:event_id])
          end

        end
      end

      # determines the unique events
      def new_events
        @new_events ||= features.lazy.map(&method(:wrap_feature)).map(&method(:build_event)).select(&method(:save_event?)).force
      end

      # wrap feature in a helper class to
      # provide method access to nested attributes
      # and granular control over the values
      def wrap_feature(feature)
        Feature.new(feature)
      end

      # build event instance from the wrapped
      # feature and assign the publisher
      def build_event(feature)
        Event.new do |e|
          e.publisher_id = publisher.id
          e.feature_id   = feature.id
          e.title        = feature.title
          e.description  = feature.description
          e.geom         = feature.geometry
          e.properties   = feature.properties
        end
      end

      # attempt to save the event, relying on
      # model validations for deduplication,
      # select if the event has not been seen before.
      def save_event?(event)
        Citygram::Models::Event.set_allowed_columns(
          :title,
          :geom,
          :description,
          :properties
        )

        if event.save
          # puts "Event is new"
          event.save
        else
          # puts "Event is old"
          existing_event = Citygram::Models::Event.find(:feature_id => event.feature_id, :publisher_id => event.publisher_id)
          puts event.title.to_s.gsub("\n", ' ').squeeze(' ') + "Event are updating" unless !existing_event.need_update(event)

          if (existing_event.need_update(event))
            existing_event.update(:title => event.title.squeeze(' '), :geom => event.geom, :description => event.description, :properties => event.properties)
          end
        end
      end

      class Feature < Struct.new(:data)
        def id
          data['id'] || properties['id']
        end

        def title
          properties['title']
        end

        def description
          properties['description']
        end

        def geometry
          data['geometry'].to_json
        end

        def properties
          data['properties'] || {}
        end
      end
    end
  end
end
