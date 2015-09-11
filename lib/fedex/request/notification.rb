require 'fedex/request/base'

module Fedex
  module Request
    class Notification < Base

      def initialize(credentials, options={})
        requires!(options, :tracking_number, :sender_email_address, :sender_name, :recipient_email)

        @debug = (ENV['DEBUG'] == 'true')

        @tracking_number        = options[:tracking_number]
        @sender_email_address   = options[:sender_email_address]
        @sender_name            = options[:sender_name]
        @recipient_email        = options[:recipient_email]
        @credentials            = credentials

        # Optionals
        @uuid                   = options[:uuid]
        @recipient_type         = options[:recipient_type] || 'RECIPIENT'
      end

      def process_request
        api_response = self.class.post(api_url, :body => build_xml)
        puts api_response if @debug == true
        response = parse_response(api_response)

        if success?(response)
          # transaction = response[:send_notifications_reply][:transaction_detail]
          # transaction[:customer_transaction_id]
          response[:send_notifications_reply]
        else
          error_message = if response[:send_notifications_reply]
            notifications = (response[:send_notifications_reply][:notifications].is_a?(Hash)) ? response[:send_notifications_reply][:notifications] : response[:send_notifications_reply][:notifications].first
            notifications[:message]
          else
            "#{api_response["Fault"]["detail"]["fault"]["cause"]}\n--#{api_response["Fault"]["detail"]["fault"]["desc"]}"
          end rescue $1
          raise RateError, error_message
        end
      end

      private

      # Build xml Fedex Web Service request
      def build_xml
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.SendNotificationsRequest(:xmlns => "http://fedex.com/ws/track/v#{service[:version]}"){
            add_web_authentication_detail(xml)
            add_client_detail(xml)
            add_transaction_details(xml)
            add_version(xml)
            xml.TrackingNumber @tracking_number
            xml.TrackingNumberUniqueId @uuid if @uuid
            xml.SenderEMailAddress @sender_email_address
            xml.SenderContactName @sender_name
            add_notification_detail(xml)
          }
        end
        builder.doc.root.to_xml
      end

      def service
        { :id => 'trck', :version => 10 }
      end

      def add_notification_detail(xml)
        xml.NotificationDetail{
          xml.Recipients {
            xml.EMailNotificationRecipientType @recipient_type
            xml.EMailAddress @recipient_email
            xml.NotificationEventsRequested 'ON_EXCEPTION'
            xml.NotificationEventsRequested 'ON_DELIVERY'
            xml.Format 'HTML'
            xml.Localization {
              xml.LanguageCode 'en'
            }
          }
        }
      end

      def add_transaction_details(xml)
        xml.TransactionDetail{
          xml.CustomerTransactionId 'SendNotification'
          xml.Localization{
            xml.LanguageCode 'en'
          }
        }
      end

      # Successful request
      def success?(response)
        response[:send_notifications_reply] &&
          %w{SUCCESS WARNING NOTE}.include?(response[:send_notifications_reply][:highest_severity])
      end

    end
  end
end
