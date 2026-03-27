defmodule PhoenixKitComments.Web.Settings do
  @moduledoc """
  LiveView for Comments module settings management.

  Manages:
  - `comments_enabled` toggle
  - `comments_moderation` toggle
  - `comments_max_depth` input
  - `comments_max_length` input

  ## Route

  Mounted at `{prefix}/admin/settings/comments`.
  """

  use PhoenixKitWeb, :live_view

  alias PhoenixKit.Settings
  alias PhoenixKit.Users.Auth.Scope

  @impl true
  def mount(_params, _session, socket) do
    project_title = Settings.get_project_title()

    socket =
      socket
      |> assign(:page_title, "Comments Settings")
      |> assign(:project_title, project_title)
      |> assign(:saving, false)
      |> load_settings()

    {:ok, socket}
  end

  @impl true
  def handle_event("save", params, socket) do
    # Verify authorization before saving
    case check_authorization(socket) do
      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "Not authorized")}

      :ok ->
        do_save_settings(params, socket)
    end
  end

  @impl true
  def handle_event("reset_defaults", _params, socket) do
    case check_authorization(socket) do
      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "Not authorized")}

      :ok ->
        defaults = %{
          "comments_enabled" => "false",
          "comments_moderation" => "false",
          "comments_max_depth" => "10",
          "comments_max_length" => "10000"
        }

        Enum.each(defaults, fn {key, value} ->
          Settings.update_setting(key, value)
        end)

        {:noreply,
         socket
         |> put_flash(:info, "Settings reset to defaults")
         |> load_settings()}
    end
  end

  ## --- Private ---

  defp do_save_settings(params, socket) do
    socket = assign(socket, :saving, true)
    settings = Map.get(params, "settings", %{})

    try do
      results =
        Enum.map(settings, fn {key, value} ->
          Settings.update_setting(key, value)
        end)

      socket =
        if Enum.all?(results, fn
             {:ok, _} -> true
             _ -> false
           end) do
          socket
          |> put_flash(:info, "Settings saved successfully")
          |> load_settings()
        else
          put_flash(socket, :error, "Failed to save some settings")
        end

      {:noreply, assign(socket, :saving, false)}
    rescue
      e ->
        require Logger
        Logger.error("Comment settings save failed: #{Exception.message(e)}")

        {:noreply,
         assign(socket, :saving, false)
         |> put_flash(:error, "Something went wrong. Please try again.")}
    end
  end

  defp load_settings(socket) do
    socket
    |> assign(:comments_enabled, Settings.get_setting("comments_enabled", "false"))
    |> assign(:comments_moderation, Settings.get_setting("comments_moderation", "false"))
    |> assign(:comments_max_depth, Settings.get_setting("comments_max_depth", "10"))
    |> assign(:comments_max_length, Settings.get_setting("comments_max_length", "10000"))
  end

  defp check_authorization(socket) do
    scope = socket.assigns[:phoenix_kit_current_scope]

    if scope && Scope.has_module_access?(scope, "comments") do
      :ok
    else
      {:error, :unauthorized}
    end
  end
end
