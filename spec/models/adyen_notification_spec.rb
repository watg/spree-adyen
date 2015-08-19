require 'spec_helper'

describe AdyenNotification do
  let!(:payment) { create(:payment, response_code: params["pspReference"]) }
  let(:notification) { subject.class.log(params)}

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
      "paymentMethod"=>"visa",
      "currency"=>"USD",
      "live"=>"false" }
  end


  
  context "with a payment" do
    it "calls handle! and capture!" do
      notification.should_receive(:capture!).once.with(payment)
      notification.should_receive(:handle!).once.with(payment)
      notification.handle_and_capture!
    end
  end

  context "without a payment" do
    before { payment.delete }
    it "does not handle! and capture!" do
      notification.should_not_receive(:capture!)
      notification.should_not_receive(:handle!)
      notification.handle_and_capture!
    end
  end


  context "receives notification of unsucessful payment auth" do
    let(:notification) { subject.class.log(params.merge("success"=>"false")) }

    it "invalidates payment" do
      expect(payment.reload).not_to be_invalid

      notification.handle!(payment)
      expect(payment.reload).to be_invalid
    end

    it "does not capture" do
      payment.should_not_receive(:capture!)
      notification.capture!(payment)
    end

  end

  context "receives notification of sucessful payment auth" do
    let(:notification) { subject.class.log(params.merge("success"=>"true")) }

    it "captures" do
      payment.should_receive(:capture!).once
      notification.capture!(payment)
    end

    it "doesnt invalidate payment" do
      notification.handle!(payment)
      expect(payment.reload).not_to be_invalid
    end
  end

  context "receives notification of sucessful payment but wrong event_code" do
    let(:notification) { subject.class.log(params.merge("success"=>"true", "event_code" => "FOO")) }

    it "does not capture" do
      payment.should_not_receive(:capture!)
      notification.capture!(payment)
    end

  end

end
