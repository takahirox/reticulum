defmodule RetWeb.Resolvers.RoomResolver do
  @moduledoc """
  Resolvers for room queries and mutations via the graphql API
  """
  alias Ret.{Hub, Repo}
  alias RetWeb.Api.V1.{HubView}
  import Canada, only: [can?: 2]

  def my_rooms(_parent, args, %{context: %{account: account}}) do
    {:ok, Hub.get_my_rooms(account, args)}
  end

  def my_rooms(_parent, _args, _resolutions) do
    {:error, "Not authorized"}
  end

  def favorite_rooms(_parent, args, %{context: %{account: account}}) do
    {:ok, Hub.get_favorite_rooms(account, args)}
  end

  def favorite_rooms(_parent, _args, _resolutions) do
    {:error, "Not authorized"}
  end

  def public_rooms(_parent, args, _resolutions) do
    {:ok, Hub.get_public_rooms(args)}
  end

  def create_room(_parent, args, %{context: %{account: account}}) do
    args = Map.put(args, :name, Map.get(args, :name, "Delightful Cooperative Meetup"))

    case Hub.create(args) do
      {:ok, hub} ->
        hub
        |> Hub.add_attrs_to_changeset(args)
        |> Hub.maybe_add_member_permissions(hub, args)
        |> Hub.maybe_add_promotion(account, hub, args)
        |> maybe_add_new_scene_to_changeset(args)
        |> Hub.changeset_for_creator_assignment(account, hub.creator_assignment_token)
        |> Repo.update()

      {:error, reason} ->
        {:error, reason}
    end
  end

  def create_room(_parent, args, _resolutions) do
    Hub.create(args)
  end

  def embed_token(hub, _args, %{context: %{account: account}}) do
    if account |> can?(embed_hub(hub)) do
      {:ok, hub.embed_token}
    else
      {:ok, nil}
    end
  end

  def embed_token(_hub, _args, _resolutions) do
    {:ok, nil}
  end

  def port(_hub, _args, _resolutions) do
    {:ok, Hub.janus_port()}
  end

  def turn(_hub, _args, _resolutions) do
    {:ok, Hub.generate_turn_info()}
  end

  def member_permissions(hub, _args, _resolutions) do
    {:ok, Hub.member_permissions_for_hub_as_atoms(hub)}
  end

  def room_size(hub, _args, _resolutions) do
    {:ok, Hub.room_size_for(hub)}
  end

  def member_count(hub, _args, _resolutions) do
    {:ok, Hub.member_count_for(hub)}
  end

  def lobby_count(hub, _args, _resolutions) do
    {:ok, Hub.lobby_count_for(hub)}
  end

  # def scene(hub, _args, _resolutions) do
  #  {:ok, Hub.scene_or_scene_listing_for(hub)}
  # end

  def update_room(_, %{id: hub_sid} = args, %{context: %{account: account}}) do
    hub = Hub |> Repo.get_by(hub_sid: hub_sid) |> Repo.preload([:hub_role_memberships, :hub_bindings])
    update_room_with_account(hub, account, args)
  end

  defp update_room_with_account(nil, _account, %{id: hub_sid}) do
    {:error, "Cannot find room with id " <> hub_sid}
  end

  defp update_room_with_account(hub, account, args) do
    case can?(account, update_roles(hub)) do
      false ->
        {:error, "Account does not have permission to update this hub."}

      true ->
        changeset =
          hub
          |> Hub.add_attrs_to_changeset(args)
          |> Hub.maybe_add_member_permissions(hub, args)
          |> Hub.maybe_add_promotion(account, hub, args)
          |> maybe_add_new_scene_to_changeset(args)

        try_do_update_room(changeset, account)
    end
  end

  defp maybe_add_new_scene_to_changeset(changeset, %{scene_id: scene_id}) do
    scene_or_scene_listing = Hub.get_scene_or_scene_listing_by_id(scene_id)

    if is_nil(scene_or_scene_listing) do
      {:error, "Cannot find scene with id " <> scene_id}
    else
      Hub.add_new_scene_to_changeset(changeset, scene_or_scene_listing)
    end
  end

  defp maybe_add_new_scene_to_changeset(changeset, _args) do
    changeset
  end

  defp try_do_update_room({:error, reason}, _) do
    {:error, reason}
  end

  defp try_do_update_room(changeset, account) do
    case changeset |> Repo.update() do
      {:error, changeset} ->
        {:error, changeset}

      {:ok, hub} ->
        hub = Repo.preload(hub, Hub.hub_preloads())

        case broadcast_hub_refresh(hub, account) do
          {:error, reason} -> {:error, reason}
          :ok -> {:ok, hub}
        end
    end
  end

  defp broadcast_hub_refresh(hub, account) do
    payload =
      HubView.render("show.json", %{
        hub: hub,
        embeddable: account |> can?(embed_hub(hub))
      })
      |> Map.put(:stale_fields, [
        # TODO: Only include fields that have changed in stale_fields
        "name",
        "description",
        "member_permissions",
        "room_size",
        "allow_promotion",
        "scene",
        "member_permissions"
      ])

    # TODO: Update client so we can use hub_refresh without socket_id
    RetWeb.Endpoint.broadcast("hub:" <> hub.hub_sid, "hub_refresh_by_api", payload)
  end
end