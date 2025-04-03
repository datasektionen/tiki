defmodule Tiki.S3 do
  def presign_url(key, opts \\ []) do
    options = Keyword.merge(get_options(key), opts)
    ReqS3.presign_url(options)
  end

  def presign_form(entry) do
    options = Keyword.merge(get_options(entry.client_name), content_type: entry.client_type)
    ReqS3.presign_form(options)
  end

  defp get_options(key) do
    env = Application.get_env(:tiki, Tiki.S3)

    [
      access_key_id: env[:access_key_id],
      secret_access_key: env[:secret_access_key],
      region: env[:region],
      bucket: env[:bucket],
      endpoint_url: env[:endpoint_frontend_url],
      key: "uploads/#{key}"
    ]
  end
end
