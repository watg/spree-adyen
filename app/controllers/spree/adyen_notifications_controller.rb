module Spree
  class AdyenNotificationsController < StoreController
    skip_before_filter :verify_authenticity_token

    before_filter :authenticate

    def notify
      @notification = AdyenNotification.log(params)
      @notification.handle!

      if @notification.successful_authorisation?
        payment = Spree::Payment.find_by(response_code: @notification.psp_reference)
        if payment
          payment.delay(run_at: 2.minutes.from_now).capture!
        end
      end
      
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
      # Validation failed, because of the duplicate check.
      # So ignore this notification, it is already stored and handled.
    ensure
      # Always return that we have accepted the notification
      render :text => '[accepted]'
    end

    protected
      # Enable HTTP basic authentication
      def authenticate
        authenticate_or_request_with_http_basic do |username, password|
          username == ENV['ADYEN_NOTIFY_USER'] && password == ENV['ADYEN_NOTIFY_PASSWD']
        end
      end
  end
end
