import Config

config :ex_telegram, api_id: System.get_env("TDLIB_API_ID")
config :ex_telegram, api_hash: System.get_env("TDLIB_API_HASH")
