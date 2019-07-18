defmodule RetWeb.HubChannel do
  @moduledoc "Ret Web Channel for Hubs"

  use RetWeb, :channel

  import Canada, only: [can?: 2]

  alias Ret.{
    Hub,
    Account,
    AccountFavorite,
    Repo,
    RoomObject,
    OwnedFile,
    Scene,
    Storage,
    SessionStat,
    Statix,
    WebPushSubscription
  }

  alias RetWeb.{Presence}
  alias RetWeb.Api.V1.{HubView}

  intercept(["mute", "naf"])

  @hub_preloads [
    scene: [:model_owned_file, :screenshot_owned_file, :scene_owned_file],
    scene_listing: [:model_owned_file, :screenshot_owned_file, :scene_owned_file, :scene],
    web_push_subscriptions: [],
    hub_bindings: [],
    created_by_account: []
  ]
  @drawing_confirm_connect 0

  def join("hub:" <> hub_sid, %{"profile" => profile, "context" => context} = params, socket) do
    hub =
      Hub
      |> Repo.get_by(hub_sid: hub_sid)
      |> Repo.preload(@hub_preloads)

    socket
    |> assign(:profile, profile)
    |> assign(:context, context)
    |> assign(:block_naf, false)
    # Pre-populate secure_scene_objects with all the pinned and scene objects in the room.
    |> assign(:secure_scene_objects, hub |> secure_scene_objects_for_hub())
    |> assign(:delivered_write_key_network_ids, [])
    |> perform_join(
      hub,
      context,
      params |> Map.take(["push_subscription_endpoint", "auth_token", "perms_token", "bot_access_key"])
    )
  end

  defp secure_scene_objects_for_hub(hub) do
    room_objects =
      hub
      |> RoomObject.room_objects_for_hub()
      |> Enum.map(&%{creator: "scene", network_id: &1.object_id, template: "#interactable-media"})

    scene_objects =
      hub.scene
      |> Scene.networked_objects_for_scene()
      |> Enum.map(&%{creator: "scene", network_id: &1["networked"]["id"], template: "#static-controlled-media"})

    room_objects ++ scene_objects
  end

  defp perform_join(socket, hub, context, params) do
    account =
      case Ret.Guardian.resource_from_token(params["auth_token"]) do
        {:ok, %Account{} = account, _claims} -> account
        _ -> nil
      end

    hub_requires_oauth = hub.hub_bindings |> Enum.empty?() |> Kernel.not()

    has_valid_bot_access_key = params["bot_access_key"] == Application.get_env(:ret, :bot_access_key)

    account_has_provider_for_hub = account |> Ret.Account.matching_oauth_providers(hub) |> Enum.empty?() |> Kernel.not()

    account_can_join = account |> can?(join_hub(hub))

    perms_token = params["perms_token"]

    has_perms_token = perms_token != nil

    decoded_perms = perms_token |> Ret.PermsToken.decode_and_verify()

    perms_token_can_join =
      case decoded_perms do
        {:ok, %{"join_hub" => true}} -> true
        _ -> false
      end

    {oauth_account_id, oauth_source} =
      case decoded_perms do
        {:ok, %{"oauth_account_id" => oauth_account_id, "oauth_source" => oauth_source}} ->
          {oauth_account_id, oauth_source |> String.to_atom()}

        _ ->
          {nil, nil}
      end

    params =
      params
      |> Map.merge(%{
        hub_requires_oauth: hub_requires_oauth,
        has_valid_bot_access_key: has_valid_bot_access_key,
        account_has_provider_for_hub: account_has_provider_for_hub,
        account_can_join: account_can_join,
        has_perms_token: has_perms_token,
        oauth_account_id: oauth_account_id,
        oauth_source: oauth_source,
        perms_token_can_join: perms_token_can_join
      })

    hub |> join_with_hub(account, socket, context, params)
  end

  def handle_in("events:entered", %{"initialOccupantCount" => occupant_count} = payload, socket) do
    socket =
      socket
      |> handle_max_occupant_update(occupant_count)
      |> handle_entered_event(payload)

    Statix.increment("ret.channels.hub.event_entered", 1)

    {:noreply, socket}
  end

  def handle_in("events:entered", payload, socket) do
    socket = socket |> handle_entered_event(payload)

    Statix.increment("ret.channels.hub.event_entered", 1)

    {:noreply, socket}
  end

  def handle_in("events:object_spawned", %{"object_type" => object_type}, socket) do
    socket = socket |> handle_object_spawned(object_type)

    Statix.increment("ret.channels.hub.objects_spawned", 1)

    {:noreply, socket}
  end

  def handle_in("events:request_support", _payload, socket) do
    hub = socket |> hub_for_socket
    Task.start_link(fn -> hub |> Ret.Support.request_support_for_hub() end)

    {:noreply, socket}
  end

  def handle_in("events:profile_updated", %{"profile" => profile}, socket) do
    socket = socket |> assign(:profile, profile) |> broadcast_presence_update
    {:noreply, socket}
  end

  def handle_in("events:begin_recording", _payload, socket), do: socket |> set_presence_flag(:recording, true)
  def handle_in("events:end_recording", _payload, socket), do: socket |> set_presence_flag(:recording, false)
  def handle_in("events:begin_streaming", _payload, socket), do: socket |> set_presence_flag(:streaming, true)
  def handle_in("events:end_streaming", _payload, socket), do: socket |> set_presence_flag(:streaming, false)

  # Captures all inbound NAF messages that result in spawned objects.
  def handle_in(
        "naf" = event,
        %{"data" => %{"isFirstSync" => true, "creator" => creator, "template" => template, "networkId" => network_id}} =
          payload,
        socket
      ) do
    account = Guardian.Phoenix.Socket.current_resource(socket)
    hub = socket |> hub_for_socket
    secure_scene_object = socket.assigns.secure_scene_objects |> Enum.find(&(&1.network_id == network_id))
    secure_template = if secure_scene_object, do: secure_scene_object.template, else: ""

    data = payload["data"]

    # TODO, client should pass this
    authorized_component_indices =
      if template |> String.ends_with?("-media") do
        [3]
      else
        []
      end

    component_write_key_payload = {network_id, authorized_component_indices}

    component_write_key =
      component_write_key_payload |> :erlang.term_to_binary() |> Ret.Crypto.encrypt() |> Base.encode64()

    authorized_broadcast =
      cond do
        template |> String.ends_with?("-avatar") ->
          data

        # If we have a secure_template for this object, and it's a static-controlled-media, that means it was part
        # of the Spoke scene and we want to allow anyone to firstSync it.
        secure_template |> String.ends_with?("static-controlled-media") ->
          data

        template |> String.ends_with?("-media") ->
          if account |> can?(spawn_and_move_media(hub)), do: data, else: data |> sanitize_data_for_ownership_transfer

        template |> String.ends_with?("-camera") ->
          if account |> can?(spawn_camera(hub)), do: data, else: nil

        template |> String.ends_with?("-drawing") ->
          if account |> can?(spawn_drawing(hub)), do: data, else: nil

        template |> String.ends_with?("-pen") ->
          if account |> can?(spawn_drawing(hub)), do: data, else: nil

        true ->
          # We want to forbid messages if they fall through the above list of template suffixes
          nil
      end

    if authorized_broadcast != nil do
      data =
        authorized_broadcast
        |> Map.put("creator", socket.assigns.session_id)
        |> Map.put("owner", socket.assigns.session_id)

      secure_scene_object = socket.assigns.secure_scene_objects |> Enum.find(&(&1.network_id == network_id))

      socket =
        if secure_scene_object == nil do
          socket
          |> assign(:secure_scene_objects, [
            %{creator: creator, network_id: network_id, template: template, write_key: component_write_key}
            | socket.assigns.secure_scene_objects
          ])
        else
          socket
        end

      payload = payload |> Map.put("data", data) |> payload_with_write_keys(socket)

      broadcast_from!(socket, event, payload)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Captures inbound NAF update messages
  def handle_in("naf" = event, %{"dataType" => "u"} = payload, socket) do
    authorized_data = payload["data"] |> authorize_object_manipulation(:remove, socket)

    if authorized_data != nil do
      payload = payload |> Map.put("data", authorized_data) |> payload_with_write_keys(socket)
      broadcast_from!(socket, event, payload)
    end

    {:noreply, socket}
  end

  # Captures inbound NAF multi update messages
  def handle_in("naf" = event, %{"dataType" => "um"} = payload, socket) do
    %{"data" => %{"d" => updates}} = payload

    filtered_updates =
      updates
      |> Enum.map(&(&1 |> authorize_object_manipulation(:update, socket)))
      |> Enum.filter(&(&1 != nil))

    if filtered_updates |> length > 0 do
      payload =
        payload |> Map.put("data", payload["data"] |> Map.put("d", filtered_updates)) |> payload_with_write_keys(socket)

      broadcast_from!(socket, event, payload)
    end

    {:noreply, socket}
  end

  # Captures inbound NAF removal messages
  def handle_in("naf" = event, %{"dataType" => "r"} = payload, socket) do
    authorized_data = payload["data"] |> authorize_object_manipulation(:remove, socket)

    if authorized_data != nil do
      payload = payload |> Map.put("data", authorized_data)
      broadcast_from!(socket, event, payload)
    end

    {:noreply, socket}
  end

  # Captures inbound NAF drawing buffer updates
  # Drawings are special since we implemented our own networking code, their data type is actually an identifier
  # for a particular instance of a networked drawing.
  def handle_in("naf" = event, %{"dataType" => "drawing-" <> drawing_network_id} = payload, socket) do
    account = Guardian.Phoenix.Socket.current_resource(socket)
    hub = socket |> hub_for_socket

    secure_scene_object = socket.assigns.secure_scene_objects |> Enum.find(&(&1.network_id == drawing_network_id))

    # If secure_scene_object is nil, we've received a message for a drawing that has not received a first sync yet,
    # or was denied creation. so just ignore it.
    if secure_scene_object != nil do
      is_creator = secure_scene_object.creator == socket.assigns.session_id

      if payload["data"]["type"] == @drawing_confirm_connect or is_creator or account |> can?(spawn_drawing(hub)) do
        broadcast_from!(socket, event, payload)
      end
    end

    {:noreply, socket}
  end

  # Fallthrough for all other dataTypes
  def handle_in("naf" = event, payload, socket) do
    broadcast_from!(socket, event, payload)
    {:noreply, socket}
  end

  def handle_in("message" = event, %{"type" => type} = payload, socket) do
    account = Guardian.Phoenix.Socket.current_resource(socket)
    hub = socket |> hub_for_socket

    if type != "photo" or account |> can?(spawn_camera(hub)) do
      broadcast!(socket, event, payload |> Map.put(:session_id, socket.assigns.session_id))
    end

    {:noreply, socket}
  end

  def handle_in("mute" = event, payload, socket) do
    hub = socket |> hub_for_socket
    account = Guardian.Phoenix.Socket.current_resource(socket)

    if account |> can?(mute_users(hub)) do
      broadcast_from!(socket, event, payload)
    end

    {:noreply, socket}
  end

  def handle_in("subscribe", %{"subscription" => subscription}, socket) do
    socket
    |> hub_for_socket
    |> WebPushSubscription.subscribe_to_hub(subscription)

    {:noreply, socket}
  end

  def handle_in("favorite", _params, socket) do
    account = Guardian.Phoenix.Socket.current_resource(socket)
    socket |> hub_for_socket |> AccountFavorite.ensure_favorited(account)
    {:noreply, socket}
  end

  def handle_in("unfavorite", _params, socket) do
    account = Guardian.Phoenix.Socket.current_resource(socket)
    socket |> hub_for_socket |> AccountFavorite.ensure_not_favorited(account)
    {:noreply, socket}
  end

  def handle_in("unsubscribe", %{"subscription" => subscription}, socket) do
    socket
    |> hub_for_socket
    |> WebPushSubscription.unsubscribe_from_hub(subscription)

    has_remaining_subscriptions = WebPushSubscription.endpoint_has_subscriptions?(subscription["endpoint"])

    {:reply, {:ok, %{has_remaining_subscriptions: has_remaining_subscriptions}}, socket}
  end

  def handle_in("sign_in", %{"token" => token} = payload, socket) do
    creator_assignment_token = payload["creator_assignment_token"]

    case Ret.Guardian.resource_from_token(token) do
      {:ok, %Account{} = account, _claims} ->
        socket = Guardian.Phoenix.Socket.put_current_resource(socket, account)

        hub = socket |> hub_for_socket |> Repo.preload(@hub_preloads)

        hub =
          if creator_assignment_token do
            hub
            |> Hub.changeset_for_creator_assignment(account, creator_assignment_token)
            |> Repo.update!()
          else
            hub
          end

        perms_token = get_perms_token(hub, account)

        if creator_assignment_token do
          broadcast_presence_update(socket)
        end

        {:reply, {:ok, %{perms_token: perms_token}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{message: "Sign in failed", reason: reason}}, socket}
    end
  end

  def handle_in("sign_out", _payload, socket) do
    socket = Guardian.Phoenix.Socket.put_current_resource(socket, nil)
    {:reply, {:ok, %{}}, socket}
  end

  def handle_in(
        "pin",
        %{
          "id" => object_id,
          "gltf_node" => gltf_node,
          "file_id" => file_id,
          "file_access_token" => file_access_token,
          "promotion_token" => promotion_token
        },
        socket
      ) do
    with_account(socket, fn account ->
      hub = socket |> hub_for_socket

      if account |> can?(pin_objects(hub)) do
        perform_pin!(object_id, gltf_node, account, socket)
        Storage.promote(file_id, file_access_token, promotion_token, account)
        OwnedFile.set_active(file_id, account.account_id)
      end
    end)
  end

  def handle_in("pin", %{"id" => object_id, "gltf_node" => gltf_node}, socket) do
    with_account(socket, fn account ->
      hub = socket |> hub_for_socket

      if account |> can?(pin_objects(hub)) do
        perform_pin!(object_id, gltf_node, account, socket)
      end
    end)
  end

  def handle_in("unpin", %{"id" => object_id, "file_id" => file_id}, socket) do
    hub = socket |> hub_for_socket

    case Guardian.Phoenix.Socket.current_resource(socket) do
      %Account{} = account ->
        if account |> can?(pin_objects(hub)) do
          RoomObject.perform_unpin(hub, object_id)
          OwnedFile.set_inactive(file_id, account.account_id)
        end

      _ ->
        nil
    end

    {:noreply, socket}
  end

  def handle_in("unpin", %{"id" => object_id}, socket) do
    hub = socket |> hub_for_socket

    case Guardian.Phoenix.Socket.current_resource(socket) do
      %Account{} = account ->
        if account |> can?(pin_objects(hub)) do
          RoomObject.perform_unpin(hub, object_id)
        end

      _ ->
        nil
    end

    {:noreply, socket}
  end

  def handle_in("get_host", _args, socket) do
    hub = socket |> hub_for_socket |> Hub.ensure_host()
    {:reply, {:ok, %{host: hub.host}}, socket}
  end

  def handle_in("update_hub", payload, socket) do
    hub = socket |> hub_for_socket
    account = Guardian.Phoenix.Socket.current_resource(socket)

    name_changed = hub.name != payload["name"]

    stale_fields = if name_changed, do: ["member_permissions", "name"], else: ["member_permissions"]

    if account |> can?(update_hub(hub)) do
      hub
      |> Hub.add_name_to_changeset(payload)
      |> Hub.add_member_permissions_to_changeset(payload)
      |> Repo.update!()
      |> Repo.preload(@hub_preloads)
      |> broadcast_hub_refresh!(socket, stale_fields)
    end

    {:noreply, socket}
  end

  def handle_in("close_hub", _payload, socket) do
    socket |> handle_entry_mode_change(:deny)
  end

  def handle_in("update_scene", %{"url" => url}, socket) do
    hub = socket |> hub_for_socket |> Repo.preload([:scene, :scene_listing])
    account = Guardian.Phoenix.Socket.current_resource(socket)

    if account |> can?(update_hub(hub)) do
      endpoint_host = RetWeb.Endpoint.host()

      case url |> URI.parse() do
        %URI{host: ^endpoint_host, path: "/scenes/" <> scene_path} ->
          scene_or_listing = scene_path |> String.split("/") |> Enum.at(0) |> Scene.scene_or_scene_listing_by_sid()
          hub |> Hub.changeset_for_new_scene(scene_or_listing)

        _ ->
          hub |> Hub.changeset_for_new_environment_url(url)
      end
      |> Repo.update!()
      |> Repo.preload(@hub_preloads, force: true)
      |> broadcast_hub_refresh!(socket, ["scene"])
    end

    {:noreply, socket}
  end

  def handle_in(
        "refresh_perms_token",
        _args,
        %{assigns: %{oauth_account_id: oauth_account_id, oauth_source: oauth_source}} = socket
      )
      when oauth_account_id != nil do
    perms_token =
      socket
      |> hub_for_socket
      |> get_perms_token(%Ret.OAuthProvider{
        provider_account_id: oauth_account_id,
        source: oauth_source
      })

    {:reply, {:ok, %{perms_token: perms_token}}, socket}
  end

  def handle_in("refresh_perms_token", _args, socket) do
    account = Guardian.Phoenix.Socket.current_resource(socket)
    perms_token = socket |> hub_for_socket |> get_perms_token(account)
    {:reply, {:ok, %{perms_token: perms_token}}, socket}
  end

  def handle_in("kick", %{"session_id" => session_id}, socket) do
    account = Guardian.Phoenix.Socket.current_resource(socket)
    hub = socket |> hub_for_socket

    if account |> can?(kick_users(hub)) do
      RetWeb.Endpoint.broadcast("session:#{session_id}", "disconnect", %{})
    end

    {:noreply, socket}
  end

  def handle_in("block_naf", _payload, socket), do: {:noreply, socket |> assign(:block_naf, true)}
  def handle_in("unblock_naf", _payload, socket), do: {:noreply, socket |> assign(:block_naf, false)}

  def handle_in(_message, _payload, socket) do
    {:noreply, socket}
  end

  def handle_out("mute" = event, %{"session_id" => session_id} = payload, socket) do
    if socket.assigns.session_id == session_id do
      push(socket, event, payload)
    end

    {:noreply, socket}
  end

  def handle_out("naf" = event, payload, socket) do
    # Sockets can block NAF as an optimization, eg iframe embeds do not need NAF messages until user clicks load
    socket =
      if !socket.assigns.block_naf do
        # Send the write keys if we have yet to send one for any of the network ids in this message
        network_ids = payload |> network_ids_for_payload
        delivered_write_key_network_ids = socket.assigns.delivered_write_key_network_ids
        can_skip_write_keys = Enum.all?(network_ids, fn id -> Enum.member?(delivered_write_key_network_ids, id) end)

        {payload, socket} =
          if can_skip_write_keys do
            {payload |> Map.delete("write_keys"), socket}
          else
            new_delivered_network_ids = (delivered_write_key_network_ids ++ network_ids) |> Enum.uniq() |> Enum.into([])
            socket = socket |> assign(:delivered_write_key_network_ids, new_delivered_network_ids)

            {payload, socket}
          end

        push(socket, event, payload)
        socket
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_out("mute", _payload, socket), do: {:noreply, socket}

  defp payload_with_write_keys(payload, socket),
    do: payload |> Map.put("write_keys", write_keys_for_payload(payload, socket))

  defp write_keys_for_payload(payload, socket) do
    payload
    |> network_ids_for_payload
    |> Enum.map(&{&1, write_key_for_network_id(&1, socket)})
    |> Enum.into(%{})
  end

  defp network_ids_for_payload(%{"data" => %{"networkId" => network_id}}), do: [network_id]
  defp network_ids_for_payload(%{"data" => %{"d" => updates}}), do: updates |> Enum.map(&get_in(&1, ["networkId"]))

  defp write_key_for_network_id(network_id, socket) do
    secure_scene_object = socket.assigns.secure_scene_objects |> Enum.find(&(&1.network_id == network_id))

    if secure_scene_object do
      secure_scene_object[:write_key]
    else
      nil
    end
  end

  defp authorize_object_manipulation(%{"networkId" => network_id} = data, type, socket) do
    account = Guardian.Phoenix.Socket.current_resource(socket)
    hub = socket |> hub_for_socket

    secure_scene_object = socket.assigns.secure_scene_objects |> Enum.find(&(&1.network_id == network_id))

    if secure_scene_object == nil do
      # It seems we've received an object manipulation message for an object that has not received a first sync yet, 
      # or was denied creation, so just ignore it.
      nil
    else
      is_creator = secure_scene_object.creator == socket.assigns.session_id
      secure_template = secure_scene_object.template

      cond do
        secure_template |> String.ends_with?("-avatar") ->
          data

        secure_template |> String.ends_with?("static-controlled-media") ->
          if type == :update, do: data, else: nil

        secure_template |> String.ends_with?("-media") ->
          is_pinned = Repo.get_by(RoomObject, object_id: network_id) != nil

          authorized =
            (!is_pinned or account |> can?(pin_objects(hub))) and
              (is_creator or account |> can?(spawn_and_move_media(hub)))

          # We need to allow for ownership transfer on media 
          if authorized, do: data, else: data |> sanitize_data_for_ownership_transfer

        secure_template |> String.ends_with?("-camera") ->
          if is_creator or account |> can?(spawn_camera(hub)), do: data, else: nil

        secure_template |> String.ends_with?("-pen") ->
          if is_creator or account |> can?(spawn_drawing(hub)), do: data, else: nil

        true ->
          # We want to forbid messages if they fall through the above list of template suffixes
          nil
      end
    end
  end

  defp sanitize_data_for_ownership_transfer(data) do
    data |> Map.take(["lastOwnerTime", "networkId", "owner"]) |> Map.put("components", %{})
  end

  defp handle_entry_mode_change(socket, entry_mode) do
    hub = socket |> hub_for_socket
    account = Guardian.Phoenix.Socket.current_resource(socket)

    if account |> can?(close_hub(hub)) do
      hub
      |> Hub.changeset_for_entry_mode(entry_mode)
      |> Repo.update!()
      |> Repo.preload(@hub_preloads)
      |> broadcast_hub_refresh!(socket, ["entry_mode"])
    end

    {:noreply, socket}
  end

  defp with_account(socket, handler) do
    case Guardian.Phoenix.Socket.current_resource(socket) do
      %Account{} = account ->
        handler.(account)
        {:reply, {:ok, %{}}, socket}

      _ ->
        # client should have signed-in at this point,
        # so if we still don't have an account, it must have been an invalid token
        {:reply, {:error, %{reason: :invalid_token}}, socket}
    end
  end

  def handle_info({:begin_tracking, session_id, _hub_sid}, socket) do
    {:ok, _} = Presence.track(socket, session_id, socket |> presence_meta_for_socket)
    push(socket, "presence_state", socket |> Presence.list())

    {:noreply, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  defp perform_pin!(object_id, gltf_node, account, socket) do
    hub = socket |> hub_for_socket
    RoomObject.perform_pin!(hub, account, %{object_id: object_id, gltf_node: gltf_node})
    broadcast_pinned_media(socket, object_id, gltf_node)
  end

  def terminate(_reason, socket) do
    socket
    |> SessionStat.stat_query_for_socket()
    |> Repo.update_all(set: [ended_at: NaiveDateTime.utc_now()])

    :ok
  end

  defp set_presence_flag(socket, flag, value) do
    socket = socket |> assign(flag, value) |> broadcast_presence_update
    {:noreply, socket}
  end

  defp broadcast_presence_update(socket) do
    Presence.update(socket, socket.assigns.session_id, socket |> presence_meta_for_socket)
    socket
  end

  defp broadcast_pinned_media(socket, object_id, gltf_node) do
    broadcast!(socket, "pin", %{object_id: object_id, gltf_node: gltf_node, pinned_by: socket.assigns.session_id})
  end

  # Broadcasts the full hub info as well as an (optional) list of specific fields which
  # clients should consider stale and need to be updated in client state from the new
  # hub info
  #
  # Note this doesn't necessarily mean the fields have changed.
  #
  # For example, if the scene needs to be refreshed, this message indicates that by including
  # "scene" in the list of stale fields.
  defp broadcast_hub_refresh!(hub, socket, stale_fields) do
    account = Guardian.Phoenix.Socket.current_resource(socket)

    response =
      HubView.render("show.json", %{hub: hub, embeddable: account |> can?(embed_hub(hub))})
      |> Map.put(:session_id, socket.assigns.session_id)
      |> Map.put(:stale_fields, stale_fields)

    broadcast!(socket, "hub_refresh", response)
  end

  defp presence_meta_for_socket(socket) do
    hub = socket |> hub_for_socket
    account = Guardian.Phoenix.Socket.current_resource(socket)

    socket.assigns
    |> maybe_override_display_name(account)
    |> Map.put(:roles, hub |> Hub.roles_for_account(account))
    |> Map.take([:presence, :profile, :context, :roles, :streaming, :recording])
  end

  # Hubs Bot can set their own display name.
  defp maybe_override_display_name(
         %{
           hub_requires_oauth: true,
           has_valid_bot_access_key: true
         } = assigns,
         _account
       ),
       do: assigns

  # Do a direct display name lookup for OAuth users without a verified email (and thus, no Hubs account).
  defp maybe_override_display_name(
         %{
           hub_requires_oauth: true,
           hub_sid: hub_sid,
           oauth_source: oauth_source,
           oauth_account_id: oauth_account_id
         } = assigns,
         _account
       )
       when not is_nil(oauth_source) and not is_nil(oauth_account_id) do
    hub = Hub |> Repo.get_by(hub_sid: hub_sid) |> Repo.preload(:hub_bindings)

    # Assume hubs only have a single hub binding for now.
    hub_binding = hub.hub_bindings |> Enum.at(0)

    oauth_provider = %Ret.OAuthProvider{
      source: oauth_source,
      provider_account_id: oauth_account_id
    }

    assigns |> override_display_name_via_binding(oauth_provider, hub_binding)
  end

  # If there isn't an oauth account id on the socket, we expect the user to have an account
  defp maybe_override_display_name(
         %{
           hub_requires_oauth: true,
           hub_sid: hub_sid,
           oauth_account_id: oauth_account_id
         } = assigns,
         account
       )
       when is_nil(oauth_account_id) do
    hub = Hub |> Repo.get_by(hub_sid: hub_sid) |> Repo.preload(:hub_bindings)

    # Assume hubs only have a single hub binding for now.
    hub_binding = hub.hub_bindings |> Enum.at(0)

    # There's no way tell which oauth_provider a user would like to identify with. We're just going to pick
    # the first one for now.
    oauth_provider =
      account.oauth_providers |> Enum.filter(fn provider -> hub_binding.type == provider.source end) |> Enum.at(0)

    assigns |> override_display_name_via_binding(oauth_provider, hub_binding)
  end

  # We don't override display names for unbound hubs
  defp maybe_override_display_name(
         %{
           hub_requires_oauth: false
         } = assigns,
         _account
       ),
       do: assigns

  defp override_display_name_via_binding(assigns, oauth_provider, hub_binding) do
    display_name = oauth_provider |> Ret.HubBinding.fetch_display_name(hub_binding)
    community_identifier = oauth_provider |> Ret.HubBinding.fetch_community_identifier()

    overriden =
      assigns.profile
      |> Map.merge(%{
        "displayName" => display_name,
        "communityIdentifier" => community_identifier
      })

    assigns |> Map.put(:profile, overriden)
  end

  defp join_with_hub(nil, _account, _socket, _context, _params) do
    Statix.increment("ret.channels.hub.joins.not_found")

    {:error, %{message: "No such Hub"}}
  end

  defp join_with_hub(%Hub{entry_mode: :deny}, _account, _socket, _context, _params) do
    {:error, %{message: "Hub no longer accessible", reason: "closed"}}
  end

  defp join_with_hub(
         %Hub{},
         %Account{},
         _socket,
         _context,
         %{
           hub_requires_oauth: true,
           account_has_provider_for_hub: true,
           account_can_join: false
         }
       ),
       do: deny_join()

  defp join_with_hub(
         %Hub{},
         nil = _account,
         _socket,
         _context,
         %{
           hub_requires_oauth: true,
           has_valid_bot_access_key: false,
           has_perms_token: true,
           perms_token_can_join: false
         }
       ),
       do: deny_join()

  defp join_with_hub(
         %Hub{} = hub,
         %Account{},
         _socket,
         _context,
         %{
           hub_requires_oauth: true,
           account_has_provider_for_hub: false
         }
       ),
       do: require_oauth(hub)

  defp join_with_hub(
         %Hub{} = hub,
         nil = _account,
         _socket,
         _context,
         %{
           hub_requires_oauth: true,
           has_valid_bot_access_key: false,
           has_perms_token: false
         }
       ),
       do: require_oauth(hub)

  defp join_with_hub(%Hub{} = hub, account, socket, context, params) do
    hub = hub |> Hub.ensure_valid_entry_code!() |> Hub.ensure_host()

    if context["embed"] do
      hub
      |> Hub.changeset_for_seen_embedded_hub()
      |> Repo.update!()
    end

    push_subscription_endpoint = params["push_subscription_endpoint"]

    is_push_subscribed =
      push_subscription_endpoint &&
        hub.web_push_subscriptions |> Enum.any?(&(&1.endpoint == push_subscription_endpoint))

    is_favorited = AccountFavorite.timestamp_join_if_favorited(hub, account)

    socket = Guardian.Phoenix.Socket.put_current_resource(socket, account)

    with socket <-
           socket
           |> assign(:hub_sid, hub.hub_sid)
           |> assign(:hub_requires_oauth, params[:hub_requires_oauth])
           |> assign(:presence, :lobby)
           |> assign(:oauth_account_id, params[:oauth_account_id])
           |> assign(:oauth_source, params[:oauth_source])
           |> assign(:has_valid_bot_access_key, params[:has_valid_bot_access_key]),
         response <- HubView.render("show.json", %{hub: hub, embeddable: account |> can?(embed_hub(hub))}) do
      perms_token = params["perms_token"] || get_perms_token(hub, account)

      response =
        response
        |> Map.put(:session_id, socket.assigns.session_id)
        |> Map.put(:session_token, socket.assigns.session_id |> Ret.SessionToken.token_for_session())
        |> Map.put(:subscriptions, %{web_push: is_push_subscribed, favorites: is_favorited})
        |> Map.put(:perms_token, perms_token)
        |> Map.put(:hub_requires_oauth, params[:hub_requires_oauth])

      existing_stat_count =
        socket
        |> SessionStat.stat_query_for_socket()
        |> Repo.all()
        |> length

      unless existing_stat_count > 0 do
        with session_id <- socket.assigns.session_id,
             started_at <- socket.assigns.started_at,
             stat_attrs <- %{session_id: session_id, started_at: started_at},
             changeset <- %SessionStat{} |> SessionStat.changeset(stat_attrs) do
          Repo.insert(changeset)
        end
      end

      send(self(), {:begin_tracking, socket.assigns.session_id, hub.hub_sid})

      # Send join push notification if this is the first joiner
      if Presence.list(socket.topic) |> Enum.count() == 0 do
        Task.start_link(fn -> hub |> Hub.send_push_messages_for_join(push_subscription_endpoint) end)
      end

      Statix.increment("ret.channels.hub.joins.ok")

      {:ok, response, socket}
    end
  end

  defp require_oauth(hub) do
    oauth_info = hub.hub_bindings |> get_oauth_info(hub.hub_sid)
    {:error, %{message: "OAuth required", reason: "oauth_required", oauth_info: oauth_info}}
  end

  defp deny_join do
    {:error, %{message: "Join denied", reason: "join_denied"}}
  end

  defp get_oauth_info(hub_bindings, hub_sid) do
    hub_bindings
    |> Enum.map(
      &case &1 do
        %{type: :discord} -> %{type: :discord, url: Ret.DiscordClient.get_oauth_url(hub_sid)}
      end
    )
  end

  defp get_perms_token(hub, %Ret.OAuthProvider{provider_account_id: provider_account_id, source: source} = account) do
    hub
    |> Hub.perms_for_account(account)
    |> Map.put(:oauth_account_id, provider_account_id)
    |> Map.put(:oauth_source, source)
    |> Map.put(:hub_id, hub.hub_sid)
    |> Ret.PermsToken.token_for_perms()
  end

  defp get_perms_token(hub, account) do
    account_id = if account, do: account.account_id, else: nil

    hub
    |> Hub.perms_for_account(account)
    |> Account.add_global_perms_for_account(account)
    |> Map.put(:account_id, account_id |> to_string)
    |> Map.put(:hub_id, hub.hub_sid)
    |> Ret.PermsToken.token_for_perms()
  end

  defp handle_entered_event(socket, payload) do
    stat_attributes = [entered_event_payload: payload, entered_event_received_at: NaiveDateTime.utc_now()]

    # Flip context to have HMD if entered with display type
    socket =
      with %{"entryDisplayType" => display} when is_binary(display) and display != "Screen" <- payload,
           %{context: context} when is_map(context) <- socket.assigns do
        socket |> assign(:context, context |> Map.put("hmd", true))
      else
        _ -> socket
      end

    socket
    |> SessionStat.stat_query_for_socket()
    |> Repo.update_all(set: stat_attributes)

    socket |> assign(:presence, :room) |> broadcast_presence_update
  end

  defp handle_max_occupant_update(socket, occupant_count) do
    socket
    |> hub_for_socket
    |> Hub.changeset_for_new_seen_occupant_count(occupant_count)
    |> Repo.update!()

    socket
  end

  defp handle_object_spawned(socket, object_type) do
    socket
    |> hub_for_socket
    |> Hub.changeset_for_new_spawned_object_type(object_type)
    |> Repo.update!()

    socket
  end

  defp hub_for_socket(socket) do
    Repo.get_by(Hub, hub_sid: socket.assigns.hub_sid) |> Repo.preload(:hub_bindings)
  end
end
