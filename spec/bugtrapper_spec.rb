require 'rack/test'
require 'bugtrapper'
require 'webmock/rspec'
require 'pry'

RSpec.describe BugTrapper::TrapExceptions do
  include Rack::Test::Methods

  let(:app) { ->(env) { [200, env, 'Hello, World!'] } }
  let(:app_id) { 'your_app_id' }
  let(:middleware) { BugTrapper::TrapExceptions.new(app, app_id: app_id) }

  subject { middleware }

  describe '#call' do
    context 'when no exception is raised' do
      it 'calls the downstream app' do
        expect(app).to receive(:call)
        subject.call({})
      end

      it 'does not capture exceptions' do
        expect(subject).not_to receive(:capture_exceptions)
        subject.call({})
      end
    end

    context 'when an exception is raised' do
      let(:exception) { StandardError.new('Something went wrong') }

      before do
        allow(app).to receive(:call).and_raise(exception)
      end

      it 'captures the exception' do
        stub_request(:post, BugTrapper::BUGTRAPPER_API_URI)
        expect(subject).to receive(:capture_exceptions).with({}, exception)
        expect { subject.call({}) }.to raise_error(exception)
      end
    end
  end

  describe '#capture_exceptions' do
    let(:env) { {} }
    let(:error_message) { 'Something went wrong' }
    let(:exception) { RuntimeError.new(error_message) }
    let(:body) do
      exception.set_backtrace([
        '/path/to/file.rb:12:in `method1`',
        '/path/to/file.rb:24:in `method2`',
        '/path/to/file.rb:36:in `method3`'
      ])
      {
        message: exception.message,
        error_details: {
          backtrace: exception.backtrace[0..5].join("\n"),
          environment: env.first(30).to_h
        },
        application_id: app_id
      }.to_json
    end

    it 'sends a POST request to the BugTrapper API' do
      stub_request(:post, BugTrapper::BUGTRAPPER_API_URI)
        .with(
          headers: { 'Content-Type' => 'application/json' },
          body: body
        )
      expect(HTTParty).to receive(:post)
        .with(
          BugTrapper::BUGTRAPPER_API_URI,
          headers: { 'Content-Type' => 'application/json' },
          body: body
        )

      subject.send(:capture_exceptions, env, exception)
    end
  end
end