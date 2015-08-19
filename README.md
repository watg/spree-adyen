# Spree Adyen Integration

Easily integrates Adyen payments into a Spree store. It works as a wrapper
of the [awesome adyen](https://github.com/wvanbergen/adyen/) gem which contains
all basic API calls for Adyen payment services.

## Installation

Add this line to your application's Gemfile:

    gem 'spree-adyen', github: 'spree/spree-adyen'

And then execute:

    $ bundle

Copy the adyen notification migration. You'll need it to save all notifications
responses.

    $ rake railties:install:migrations

## Usage

To integrate with Adyen Payments you'll need to request API credentials by
signing up at Adyen website https://www.adyen.com/.

This extension provides three Payment Methods. In order to use AdyenPayment and
AdyenPaymentEncrypted method you'll need to make sure your account is enabled to
use Adyen API Payments, needed to authorize payments via their SOAP API.

The other payment method, AdyenHPP, allows your store to authorize payments
using Adyen Hosted Payments Page solution. In this case the customer will enter
cc in Adyen website and be redirected back to the store after the payment.

For the AdyenHPP method you'll need to create a skin in your merchant dashboard
and add the skin_code and shared_secret to the payment method on Spree backend UI.

All subsequent calls, e.g. capture, are done via Adyen SOAP API by both payment
methods.

Make sure that you config your notification settings in Adyen Merchant dashboard.
You need to set URL, choose HTTP POST and set a username and password for
authentication. The username and password need to be set as environment variables
, ADYEN_NOTIFY_USER and ADYEN_NOTIFY_PASSWD, so that notifications can successfully
persist on your application database.

Please look into the adyen gem wiki https://github.com/wvanbergen/adyen/wiki and
Adyen Integration Manual for further info https://www.adyen.com/developers/api/

## Testing

The extension contains some specs that will reach out Adyen API the first time
you run them. Those are marked with the external tag and they need credentials
so you'll have to set up a config/credentials.yml file. Theres's a helper
`test_crendentials` available on the specs to call each key on that yaml file.
Also it uses VCR to record the requests so you'll need to delete those files
to do a new request.

You can run external specs like this:

```ruby
bundle exec rspec spec --tag external
```

## Test Credit Card Info

https://support.adyen.com/index.php?/Knowledgebase/Article/View/11/0/test-card-numbers

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
