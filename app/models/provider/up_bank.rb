class Provider::UpBank
  include HTTParty
  base_uri "https://api.up.com.au/api/v1"

  class UpBankError < StandardError; end

  def initialize(access_token = nil)
    @access_token = access_token
  end

  def ping
    request(:get, "/util/ping").code == 200
  end

  def get_accounts
    paginate("/accounts")
  end

  def get_transactions(account_id: nil, since: nil, until_date: nil, page_size: 100)
    path = account_id ? "/accounts/#{account_id}/transactions" : "/transactions"
    query = { "page[size]" => page_size }
    query["filter[since]"] = since.iso8601 if since
    query["filter[until]"] = until_date.iso8601 if until_date
    paginate(path, query)
  end

  private

    def auth_headers
      { "Authorization" => "Bearer #{@access_token}", "Accept" => "application/json" }
    end

    def request(method, path_or_url, query: {})
      self.class.public_send(method, path_or_url, headers: auth_headers, query: query)
    end

    def paginate(path, query = {})
      out = []
      resp = request(:get, path, query: query)
      loop do
        raise UpBankError, "Up API #{resp.code}: #{resp.body}" unless resp.code.between?(200, 299)
        body = resp.parsed_response
        out.concat(Array(body["data"]))
        nxt = body.is_a?(Hash) ? body.dig("links", "next") : nil
        break if nxt.blank?
        # Parse absolute next URL, re-issue via base_uri so auth headers apply
        # and WebMock stubs match cleanly.
        nxt_uri = URI.parse(nxt)
        nxt_path = nxt_uri.path.sub(%r{\A/api/v1}, "")
        nxt_path = "/" if nxt_path.blank?
        nxt_query = nxt_uri.query ? URI.decode_www_form(nxt_uri.query).to_h : {}
        resp = request(:get, nxt_path, query: nxt_query)
      end
      out
    end
end
