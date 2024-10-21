client_id = "0ARzBcd1Wn0g0msUFu2Klhs8hSTdkc3nvsT-g0Jixpk="
client_secret = "oea6fpSYP3uwBjQOGx6IzA4KD_OTuJBjWMsWaQL3HZA="

{:ok, redirect_uri} =
  Oidcc.create_redirect_url(
    Tiki.OpenIdConfigurationProvider,
    client_id,
    client_secret,
    %{redirect_uri: "https://localhost:4000/callback"}
  )

{:ok, client_context} =
  Oidcc.ClientContext.from_configuration_worker(
    pid,
    client_id,
    client_secret
  )
