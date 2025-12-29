import Config

config :web,
  s3_settings: [
    base_url: System.fetch_env!("AWS_BUCKET_URL"),
    access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
    secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY"),
    service: System.fetch_env!("AWS_SERVICE"),
    region: System.fetch_env!("AWS_REGION")
  ]
