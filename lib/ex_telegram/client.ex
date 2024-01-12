defmodule ExTelegram.Client do
  @moduledoc false
  use GenServer

  alias ExTDLib.Method
  alias ExTDLib.Object

  require Logger

  @session :session

  def start_link(_) do
    GenServer.start_link(
      __MODULE__,
      %{
        config: nil,
        session: nil,
        auth_state: nil,
        users: %{},
        user_ids: [],
        chats: %{},
        chat_ids: [],
        chat_members: %{},
        supergroup_members: %{},
        supergroup_members_request: nil
      },
      name: __MODULE__
    )
  end

  def transmit(msg) do
    GenServer.cast(__MODULE__, {:transmit, msg})
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
      struct(ExTDLib.default_config(), %{
        database_directory: Path.join(:code.priv_dir(:ex_telegram), "tdlib"),
        api_id: Application.get_env(:ex_telegram, :api_id),
        api_hash: Application.get_env(:ex_telegram, :api_hash)
      })

    {:ok, _pid} = ExTDLib.open(@session, self(), config)
    ExTDLib.transmit(@session, "verbose 0")

    {:ok, %{state | config: config, session: @session}}
  end

  @impl true
  def handle_info({:recv, %Object.Users{user_ids: user_ids}}, state) do
    user_ids =
      state
      |> Map.get(:user_ids)
      |> Kernel.++(user_ids)

    state = %{state | user_ids: user_ids}

    {:noreply, state}
  end

  @impl true
  def handle_info({:recv, %Object.Chats{chat_ids: chat_ids}}, state) do
    chat_ids =
      state
      |> Map.get(:chat_ids)
      |> Kernel.++(chat_ids)

    {:noreply, %{state | chat_ids: chat_ids}}
  end

  @impl true
  def handle_info({:recv, %Object.UpdateUser{user: user}}, state), do: update_users(user, state)

  @impl true
  def handle_info({:recv, %Object.User{} = user}, state), do: update_users(user, state)

  @impl true
  def handle_info({:recv, %Object.UpdateNewChat{chat: chat}}, state) do
    chats =
      state
      |> Map.get(:chats)
      |> Map.put(to_string(chat.id), chat)

    chat_ids =
      state
      |> Map.get(:chat_ids)
      |> Kernel.++([chat.id])

    state = %{state | chats: chats, chat_ids: chat_ids}

    {:noreply, state}
  end

  @impl true
  def handle_info({:recv, %Object.UpdateUserFullInfo{}}, state) do
    # IO.inspect(user_full_info, label: "-=============== USER FULL INFO")

    {:noreply, state}
  end

  @impl true
  def handle_info({:recv, %Object.Supergroup{} = supergroup}, state) do
    IO.inspect(supergroup, label: "-=============== Supergroup")

    {:noreply, state}
  end

  @impl true
  def handle_info({:recv, %Object.SupergroupFullInfo{} = supergroup_full_info}, state) do
    IO.inspect(supergroup_full_info, label: "-=============== supergroup_full_info")

    {:noreply, state}
  end

  @impl true
  def handle_info({:recv, %Object.ChatMembers{members: members} = cm}, state) do
    IO.inspect(cm, label: "-=============== ChatMembers")

    members =
      state
      |> Map.get(:supergroup_members)
      |> Map.get(state.supergroup_members_request, [])
      |> Kernel.++(members)
      |> Enum.uniq_by(fn %{"member_id" => %{"user_id" => user_id}} -> user_id end)

    supergroup_members = Map.put(state.supergroup_members, state.supergroup_members_request, members)

    {:noreply, %{state | supergroup_members: supergroup_members, supergroup_members_request: nil}}
  end

  @impl true
  def handle_info({:recv, %Object.BasicGroup{} = info}, state) do
    IO.inspect(info, label: "-=============== BasicGroup")

    {:noreply, state}
  end

  @impl true
  def handle_info({:recv, %Object.BasicGroupFullInfo{} = full_info}, state) do
    IO.inspect(full_info, label: "-=============== BasicGroupFullInfo")

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

          # code = "Please provide authentication code: " |> IO.gets() |> String.trim()
          # query = %Method.CheckAuthenticationCode{code: code}
          # ExTDLib.transmit(@session, query)

          %Object.AuthorizationStateWaitOtherDeviceConfirmation{} ->
            IO.puts("AuthorizationStateWaitOtherDeviceConfirmation!")
            :ignore

          %Object.AuthorizationStateWaitPassword{} ->
            IO.puts("AuthorizationStateWaitPassword")

          # password = "Please provide two auth code: " |> IO.gets() |> String.trim()
          # query = %Method.CheckAuthenticationPassword{password: password}
          # ExTDLib.transmit(@session, query)

          %Object.AuthorizationStateWaitPhoneNumber{} ->
            IO.puts("AuthorizationStateWaitPhoneNumber!")

          # phone_number = "Please provide phone number: " |> IO.gets() |> String.trim()
          # query = %Method.SetAuthenticationPhoneNumber{phone_number: phone_number}
          # ExTDLib.transmit(@session, query)

          %Object.AuthorizationStateWaitRegistration{} ->
            IO.puts("AuthorizationStateWaitRegistration!")
            :ignore

          %Object.AuthorizationStateWaitTdlibParameters{} ->
            # Handled by TDLib
            :ignore
        end

        {:noreply, %{state | auth_state: auth_state}}

      _msg ->
        {:noreply, state}
    end
  end

  def handle_info(info, state) do
    IO.inspect(info, label: "-=============== OTHER INFO")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:transmit, %Method.GetSupergroupMembers{supergroup_id: supergroup_id} = msg}, state) do
    ExTDLib.transmit(@session, msg)

    {:noreply, %{state | supergroup_members_request: to_string(supergroup_id)}}
  end

  @impl true
  def handle_cast({:transmit, msg}, state) do
    ExTDLib.transmit(@session, msg)

    {:noreply, state}
  end

  @impl true
  def handle_cast(:get_chats, state) do
    query = %Method.GetChats{chat_list: nil, limit: 1000}
    ExTDLib.transmit(@session, query)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:get_chat, id}, state) do
    query = %Method.GetChat{chat_id: id}
    ExTDLib.transmit(@session, query)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:get_user, id}, state) do
    query = %Method.GetUserFullInfo{user_id: id}
    ExTDLib.transmit(@session, query)

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

    ExTDLib.transmit(@session, query)

    {:noreply, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:get_contacts, _from, state) do
    query = %Method.GetContacts{}
    ExTDLib.transmit(@session, query)

    {:reply, :ok, state}
  end

  defp update_users(user, state) do
    users =
      state
      |> Map.get(:users)
      |> Map.put(to_string(user.id), user)

    user_ids =
      state
      |> Map.get(:user_ids)
      |> Kernel.++([user.id])
      |> Enum.uniq()

    state = %{state | users: users, user_ids: user_ids}

    {:noreply, state}
  end
end
