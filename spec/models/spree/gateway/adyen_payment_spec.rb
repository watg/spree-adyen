require 'spec_helper'

module Spree
  describe Gateway::AdyenPayment do
    let(:response) do
      double("Response", psp_reference: "psp", result_code: "accepted", success?: true)
    end

    context "successfully authorized" do
      before do
        subject.stub_chain(:provider, authorise_payment: response)
      end

      it "adds processing api calls to response object" do
        result = subject.authorize(30000, create(:credit_card))

        expect(result.authorization).to eq response.psp_reference
        expect(result.cvv_result['code']).to eq response.result_code
      end
    end

    context "ensure adyen validations goes fine" do
      let(:options) do
        { order_id: 17,
          email: "surf@uk.com",
          customer_id: 1,
          ip: "127.0.0.1",
          currency: 'USD' }
      end

      before do
        subject.preferred_merchant_account = "merchant"
        subject.preferred_api_username = "admin"
        subject.preferred_api_password = "123"

        # Watch out as we're stubbing private method here to avoid reaching network
        # we might need to stub another method in future adyen gem versions
        ::Adyen::API::PaymentService.any_instance.stub(make_payment_request: response)
      end

      let(:cc) { create(:credit_card) }

      it "adds processing api calls to response object" do
        expect {
          subject.authorize(30000, cc, options)
        }.not_to raise_error

        cc.gateway_customer_profile_id = "123"
        expect {
          subject.authorize(30000, cc, options)
        }.not_to raise_error
      end

      it "calls authrorize payment with the correct arguments (currency as well)" do
        expect(subject.provider).to receive(:authorise_payment).with(17, {:currency=>"USD", :value=>30000}, anything, anything, anything).
           and_return(double('response', :success? => true))
        subject.authorize(30000, cc, options)
      end


      it "user order email as shopper reference when theres no user" do
        cc.gateway_customer_profile_id = "123"
        options[:customer_id] = nil

        expect {
          subject.authorize(30000, cc, options)
        }.not_to raise_error
      end
    end

    context "refused" do
      let(:response) do
        double("Response", success?: false, result_code: "refused", refusal_reason: "Not allowed")
      end

      before do
        subject.stub_chain(:provider, authorise_payment: response)
      end

      it "response obj print friendly message" do
        result = subject.authorize(30000, create(:credit_card))
        expect(result.to_s).to include(response.result_code)
        expect(result.to_s).to include(response.refusal_reason)
      end
    end

    context "profile creation" do
      let(:payment) { create(:payment) }

      let(:details_response) do
        card = { card: { expiry_date: 1.year.from_now, number: "1111" }, recurring_detail_reference: "123432423" }
        double("List", details: [card])
      end

      before do
        expect(subject.provider).to receive(:authorise_payment).and_return response
        expect(subject.provider).to receive(:list_recurring_details).and_return details_response
        payment.source.gateway_customer_profile_id = nil
      end

      it "authorizes payment to set up recurring transactions" do
        subject.create_profile payment
        expect(payment.source.gateway_customer_profile_id).to eq details_response.details.last[:recurring_detail_reference]
      end

      it "builds authorise details options" do
        expect(subject).to receive(:build_authorise_details)
        subject.create_profile payment
      end

      it "set payment state to processing" do
        subject.create_profile payment
        expect(payment.state).to eq "processing"
      end

      context 'without an associated user' do
        it "sets last recurring detail reference returned on payment source" do
          payment.order = Order.create number: "R2342345435", last_ip_address: "127.0.0.1"
          subject.create_profile payment

          expect(payment.source.gateway_customer_profile_id).to be_present
        end
      end
    end

    context "Adding recurring contract via $0 auth" do
      let(:shopper_ip) { "127.0.0.1" }
      let(:user) { double("User", id: 358, email: "spree@hq.com") }
      let(:source) do
        CreditCard.create! do |cc|
          cc.name = "Spree Dev Check"
          cc.verification_value = "737"
          cc.month = "06"
          cc.year = "2016"
          cc.number = "5555444433331111"
        end
      end

      before do
        subject.preferred_merchant_account = test_credentials["merchant_account"]
        subject.preferred_api_username = test_credentials["api_username"]
        subject.preferred_api_password = test_credentials["api_password"]
      end

      it "brings last recurring contract info", external: true do
        source.number = "5555444433331111"

        VCR.use_cassette "add_contract" do
          subject.add_contract source, user, shopper_ip
        end
      end
    end

    context "one click payment auth" do
      before do
        subject.stub require_one_click_payment?: true
      end

      let(:credit_card) do
        hash = {
          gateway_customer_profile_id: 1,
          verification_value: 1,
          name: "Spree",
          number: 123,
          month: 06,
          year: 2016
        }

        double("CC", hash)
      end

      it "adds processing api calls to response object" do
        expect(subject.provider).to receive(:authorise_one_click_payment).and_return response
        result = subject.authorize(30000, credit_card)
      end
    end

    context "builds authorise details" do
      let(:payment) { double("Payment", request_env: {}) }

      it "returns browser info when 3D secure is required" do
        expect(subject.build_authorise_details payment).to have_key :browser_info
      end

      context "doesnt require 3d secure" do
        before { subject.stub require_3d_secure?: false }

        it "doesnt return browser info" do
          expect(subject.build_authorise_details payment).to_not have_key :browser_info
        end
      end
    end

    context "real external profile creation", external: true do
      before do
        subject.preferred_merchant_account = test_credentials["merchant_account"]
        subject.preferred_api_username = test_credentials["api_username"]
        subject.preferred_api_password = test_credentials["api_password"]
      end

      let(:order) do
        user = stub_model(LegacyUser, email: "spree@example.com", id: rand(50))
        stub_model(Order, id: 1, number: "R#{Time.now.to_i}-test", email: "spree@example.com", last_ip_address: "127.0.0.1", user: user)
      end
      
      it "sets profiles" do
        credit_card = CreditCard.new do |cc|
          cc.name = "Washington Braga"
          cc.number = "5555444433331111"
          cc.month = "06"
          cc.year = "2016"
          cc.verification_value = "737"
        end

        payment = Payment.new do |p|
          p.order = order
          p.amount = 1
          p.source = credit_card
          p.payment_method = subject
          p.request_env = {}
        end

        order.user_id = 33242

        VCR.use_cassette("profiles/set") do
          subject.save
          payment.save!
          expect(credit_card.gateway_customer_profile_id).not_to be_empty
        end
      end

      context "3-D enrolled credit card" do
        let(:credit_card) do
          CreditCard.create! do |cc|
            cc.name = "Washington Braga"
            cc.number = "4212 3456 7890 1237"
            cc.month = "06"
            cc.year = "2016"
            cc.verification_value = "737"
          end
        end

        let(:env) do
          {
            "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:29.0) Gecko/20100101 Firefox/29.0",
            "HTTP_ACCEPT"=> "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
          }
        end

        def set_up_payment
          Payment.create! do |p|
            p.order = order
            p.amount = 1
            p.source = credit_card
            p.payment_method = subject
            p.request_env = env
          end
        end

        it "raises custom exception" do
          subject.save

          VCR.use_cassette("3D-Secure") do
            expect {
              set_up_payment
            }.to raise_error Adyen::Enrolled3DError
          end
        end

        it "doesn't persist new payments" do
          subject.save

          VCR.use_cassette("3D-Secure") do
            payments = Payment.count
            expect { set_up_payment }.to raise_error Adyen::Enrolled3DError
            expect(payments).to eq Payment.count
          end
        end

        it "authorises with payment 3d request" do
          md = test_credentials["md"]
          pa_response = test_credentials["pa_response"]
          ip = "127.0.0.1"

          VCR.use_cassette("3D-Secure-authorise") do
            expect(subject.authorise3d(md, pa_response, ip, env)).to be_success
          end
        end
      end
    end
  end
end
