defmodule Web.Req.Base do
  def base_req() do
    with nil <- :persistent_term.get({:web, :s3_base_req}, nil) do
      s3_opts = Web.Conf.s3_opts()

      base_req =
        Req.new(
          base_url: s3_opts.base_url,
          aws_sigv4: [
            access_key_id: s3_opts.access_key_id,
            secret_access_key: s3_opts.secret_access_key,
            service: s3_opts.service,
            region: s3_opts.region
          ]
        )

      :persistent_term.put({:web, :s3_base_req}, base_req)
      base_req
    end
  end
end
