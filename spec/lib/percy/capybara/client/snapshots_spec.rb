require 'json'
require 'digest'
require 'capybara'
require 'capybara/webkit'

RSpec.describe Percy::Capybara::Client::Snapshots, type: :feature do
  let(:capybara_client) { Percy::Capybara::Client.new(enabled: true) }

  describe '#snapshot', type: :feature, js: true do
    context 'simple page with no resources' do
      before(:each) { setup_sprockets(capybara_client) }
      let(:loader) { capybara_client.initialize_loader(page: page) }
      let(:build_resource_sha) { loader.build_resources.first.sha }
      let(:snapshot_resource_sha) { loader.snapshot_resources.first.sha }
      let(:mock_build_response) do
        {
          'data' => {
            'id' => '123',
            'type' => 'builds',
            'relationships' => {
              'self' => "/api/v1/snapshots/123",
              'missing-resources' => {},
            },
          },
        }
      end
      let(:mock_snapshot_response) do
        {
          'data' => {
            'id' => '256',
            'type' => 'snapshots',
            'relationships' => {
              'self' => "/api/v1/snapshots/123",
              'missing-resources' => {
                'data' => [
                  {
                    'type' => 'resources',
                    'id' => snapshot_resource_sha,
                  },
                ],
              },
            },
          },
        }
      end
      before :each do
        visit '/'
        loader  # Force evaluation now.
        stub_request(:post, 'https://percy.io/api/v1/repos/percy/percy-capybara/builds/')
          .to_return(status: 201, body: mock_build_response.to_json)
        stub_request(:post, 'https://percy.io/api/v1/builds/123/snapshots/')
          .to_return(status: 201, body: mock_snapshot_response.to_json)
          stub_request(:post, "https://percy.io/api/v1/builds/123/resources/")
            .with(body: /#{snapshot_resource_sha}/)
            .to_return(status: 201, body: {success: true}.to_json)
        stub_request(:post, "https://percy.io/api/v1/snapshots/256/finalize")
          .to_return(status: 200, body: {success: true}.to_json)
        capybara_client.initialize_build
      end

      it 'creates a snapshot' do
        expect(capybara_client.client).to receive(:create_snapshot)
          .with(anything, anything, {name: nil, widths: nil})
          .and_call_original
        expect(capybara_client.snapshot(page)).to eq(true)
      end
      it 'passes through name and width options to the percy client if given' do
        expect(capybara_client.client).to receive(:create_snapshot)
          .with(anything, anything, {name: 'foo', widths: [320, 1024]})
          .and_call_original

        expect(capybara_client.snapshot(page, name: 'foo', widths: [320, 1024])).to eq(true)
        expect(capybara_client.failed?).to eq(false)
      end
      it 'safely handles connection errors' do
        expect(capybara_client.client).to receive(:create_snapshot)
          .and_raise(Percy::Client::ConnectionFailed)
        expect(capybara_client.snapshot(page)).to eq(nil)
        expect(capybara_client.failed?).to eq(true)
      end
    end
  end
end
