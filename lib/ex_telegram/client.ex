defmodule ExTelegram.Client do
  @moduledoc false
  use GenServer

  alias TDLib.Method
  alias TDLib.Object

  require Logger

  @session :session

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{config: nil, session: nil}, name: __MODULE__)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def get_contacts do
    GenServer.call(__MODULE__, :get_contacts)
  end

  def get_chats do
    GenServer.cast(__MODULE__, :get_chats)
  end

  def get_chat(%Object.User{id: id}) do
    GenServer.cast(__MODULE__, {:get_chat, id})
  end

  def get_user(%Object.User{id: id}) do
    GenServer.cast(__MODULE__, {:get_user, id})
  end

  def send_message(%Object.User{} = user, %Object.Message{} = message) do
    GenServer.cast(__MODULE__, {:send_message, user, message})
  end

  #### Server (callbacks)

  @impl true
  def init(state) do
    config =
      struct(TDLib.default_config(), %{
        api_id: Application.get_env(:ex_telegram, :api_id),
        api_hash: Application.get_env(:ex_telegram, :api_hash)
      })

    {:ok, _pid} = TDLib.open(@session, self(), config)
    TDLib.transmit(@session, "verbose 0")

    {:ok, %{state | config: config, session: @session}}
  end

  @impl true
  def handle_info({:recv, %Object.Users{} = users}, state) do
    state = Map.put(state, :users, users)

    {:noreply, state}
  end

  @impl true
  def handle_info({:recv, msg}, state) do
    IO.puts(Map.get(msg, :"@type") <> " received.")

    case msg do
      %Object.UpdateAuthorizationState{authorization_state: auth_state} ->
        case auth_state do
          %Object.AuthorizationStateClosed{} ->
            IO.puts("AuthorizationStateClosed!")
            :ignore

          %Object.AuthorizationStateClosing{} ->
            IO.puts("AuthorizationStateClosing!")
            :ignore

          %Object.AuthorizationStateLoggingOut{} ->
            IO.puts("AuthorizationStateLoggingOut!")
            :ignore

          %Object.AuthorizationStateReady{} ->
            IO.puts("AuthorizationStateReady!")
            :ignore

          %Object.AuthorizationStateWaitCode{} ->
            IO.puts("AuthorizationStateWaitCode!")
            code = "Please provide authentication code: " |> IO.gets() |> String.trim()
            query = %Method.CheckAuthenticationCode{code: code}
            TDLib.transmit(@session, query)

          %Object.AuthorizationStateWaitOtherDeviceConfirmation{} ->
            IO.puts("AuthorizationStateWaitOtherDeviceConfirmation!")
            :ignore

          %Object.AuthorizationStateWaitPassword{} ->
            IO.puts("AuthorizationStateWaitPassword")
            password = "Please provide two auth code: " |> IO.gets() |> String.trim()
            query = %Method.CheckAuthenticationPassword{password: password}
            TDLib.transmit(@session, query)

          %Object.AuthorizationStateWaitPhoneNumber{} ->
            IO.puts("AuthorizationStateWaitPhoneNumber!")
            phone_number = "Please provide phone number: " |> IO.gets() |> String.trim()
            query = %Method.SetAuthenticationPhoneNumber{phone_number: phone_number}
            TDLib.transmit(@session, query)

          %Object.AuthorizationStateWaitRegistration{} ->
            IO.puts("AuthorizationStateWaitRegistration!")
            :ignore

          %Object.AuthorizationStateWaitTdlibParameters{} ->
            IO.puts("AuthorizationStateWaitTdlibParameters!")
            # Handled by TDLib
            :ignore
        end

      msg ->
        IO.inspect(msg, label: "-=============== MSG")
    end

    {:noreply, state}
  end

  def handle_info(info, state) do
    IO.inspect(info, label: "-=============== OTHER INFO")
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:get_contacts, _from, state) do
    query = %Method.GetContacts{}
    TDLib.transmit(@session, query)

    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(:get_chats, state) do
    query = %Method.GetChats{chat_list: nil, limit: 1000}
    TDLib.transmit(@session, query)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:get_chat, id}, state) do
    query = %Method.GetChat{chat_id: id}
    TDLib.transmit(@session, query)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:get_user, id}, state) do
    query = %Method.GetUserFullInfo{user_id: id}
    TDLib.transmit(@session, query)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_message, user, message}, state) do
    query = %Method.SendMessage{
      chat_id: user.id,
      message_thread_id: 0,
      reply_to: 0,
      options: nil,
      reply_markup: nil,
      input_message_content: %Object.InputMessageText{
        text: %Object.FormattedText{
          text: "asdf"
        }
      }
    }

    TDLib.transmit(@session, query)

    {:noreply, state}
  end
end
