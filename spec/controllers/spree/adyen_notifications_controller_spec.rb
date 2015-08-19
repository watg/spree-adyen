require 'spec_helper'

module Spree
  describe AdyenNotificationsController, type: :controller do
    context "request authenticated" do
      before do
        ENV["ADYEN_NOTIFY_USER"] = "username"
        ENV["ADYEN_NOTIFY_PASSWD"] = "password"
        @request.env["HTTP_AUTHORIZATION"] = "Basic " + Base64::encode64("username:password")
      end

      def params
        { "pspReference" => "8513823667306210",
          "eventDate"=>"2013-10-21T14:45:45.93Z",
          "merchantAccountCode"=>"Test",
          "reason"=>"41061:1111:6/2016",
          "originalReference" => "",
          "value"=>"6999",
          "eventCode"=>"AUTHORISATION",
          "merchantReference"=>"R354361834-A3JC8TNJ",
          "operations"=>"CANCEL,CAPTURE,REFUND",
          "success"=>"true",
          "paymentMethod"=>"visa",
          "currency"=>"USD",
          "live"=>"false" }
      end

      it "logs notitification" do
        delayed_notification = double 'Delayed Notification'
        AdyenNotification.any_instance.should_receive(:delay).once.and_return delayed_notification
        delayed_notification.should_receive(:handle_and_capture!)
        expect {
          spree_post :notify, params
        }.to change { AdyenNotification.count }.by(1)
      end
      
      it "captures payment if successful" do
        notification = double 'Notification'
        delayed_notification = double 'Delayed Notification'
        AdyenNotification.should_receive(:log).and_return notification
        notification.should_receive(:delay).and_return delayed_notification
        delayed_notification.should_receive(:handle_and_capture!)

        spree_post :notify, params
      end

      it "handles exception" do
        exception = Exception.new("no joy")
        #exception = ActiveRecord::RecordNotUnique.new("!23123")
        AdyenNotification.should_receive(:log).and_raise(exception)
        Rails.logger.should_receive(:error).with(/#{exception.message}/)
        spree_post :notify, params
      end

      it "handles exception ActiveRecord::RecordNotUnique" do
        exception = ActiveRecord::RecordNotUnique.new("!23123")
        AdyenNotification.should_receive(:log).and_raise(exception)
        Rails.logger.should_receive(:info).with(/#{exception.message}/)
        spree_post :notify, params
      end
    end

    context "request not authenticated" do
      it "logs notitification" do
        spree_post :notify
        expect(response.status).to eq 401
      end
    end
  end
end
