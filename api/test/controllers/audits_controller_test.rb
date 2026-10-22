require "test_helper"

class AuditsControllerTest < ActionDispatch::IntegrationTest
  context "POST /api/audits" do
    should "create an audit and return findings" do
      stub_advisory_refresh! do
        assert_difference "Audit.count", 1 do
          post "/api/audits", params: {lockfile: VULNERABLE_LOCKFILE}, as: :json
        end
      end

      assert_response :created
      body = response.parsed_body
      assert body["results"].any?
      assert_empty body["warnings"]
      refute body.key?("lockfile")
    end

    should "accept CRLF text as pasted from a browser" do
      stub_advisory_refresh! do
        post "/api/audits", params: {lockfile: VULNERABLE_LOCKFILE.gsub("\n", "\r\n")}, as: :json
      end

      assert_response :created
      assert response.parsed_body["results"].any?
    end

    should "surface the stale-database warning" do
      stub_advisory_refresh!(warning: "stale") do
        post "/api/audits", params: {lockfile: VULNERABLE_LOCKFILE}, as: :json
      end

      assert_equal ["stale"], response.parsed_body["warnings"]
    end

    should "return 422 for something that is not a lockfile" do
      assert_no_difference "Audit.count" do
        post "/api/audits", params: {lockfile: "nope"}, as: :json
      end

      assert_response :unprocessable_content
      assert response.parsed_body["errors"].any?
    end

    should "return 422 when the lockfile param is missing" do
      post "/api/audits", params: {}, as: :json

      assert_response :unprocessable_content
    end

    should "return 503 when no advisory database is available" do
      AdvisoryDatabase.stub(:refresh, -> { raise AdvisoryDatabase::Unavailable, "no db" }) do
        assert_no_difference "Audit.count" do
          post "/api/audits", params: {lockfile: VULNERABLE_LOCKFILE}, as: :json
        end
      end

      assert_response :service_unavailable
      assert_equal ["no db"], response.parsed_body["errors"]
    end
  end

  context "GET /api/audits/:id" do
    should "return a stored audit" do
      audit = Audit.create!(lockfile: VULNERABLE_LOCKFILE, results: [{"type" => "x"}])

      get "/api/audits/#{audit.id}"

      assert_response :success
      assert_equal audit.id, response.parsed_body["id"]
      assert_equal [{"type" => "x"}], response.parsed_body["results"]
    end
  end
end
