defmodule Xactions.Accounts do
  @moduledoc "Context for managing institutions and accounts."

  import Ecto.Query

  alias Xactions.Repo
  alias Xactions.Accounts.{Institution, Account}

  # --- Institutions ---

  def list_institutions do
    Repo.all(from i in Institution, order_by: [asc: i.name])
  end

  def get_institution!(id), do: Repo.get!(Institution, id)

  def create_institution(attrs) do
    %Institution{}
    |> Institution.changeset(attrs)
    |> Repo.insert()
  end

  def update_institution(institution, attrs) do
    institution
    |> Institution.changeset(attrs)
    |> Repo.update()
  end

  def update_institution_status(institution, status) do
    institution
    |> Institution.status_changeset(status)
    |> Repo.update()
  end

  def touch_synced_at(institution) do
    institution
    |> Ecto.Changeset.change(last_synced_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update()
  end

  def disconnect_institution(institution) do
    Repo.delete(institution)
  end

  # --- Accounts ---

  def list_accounts do
    Repo.all(from a in Account, order_by: [asc: a.name])
  end

  def list_accounts_for_institution(institution_id) do
    Repo.all(from a in Account, where: a.institution_id == ^institution_id, order_by: [asc: a.name])
  end

  def get_account!(id), do: Repo.get!(Account, id)

  def create_account(attrs) do
    %Account{}
    |> Account.changeset(attrs)
    |> Repo.insert()
  end

  def upsert_account(institution_id, %{external_account_id: ext_id} = attrs)
      when not is_nil(ext_id) do
    existing =
      Repo.one(
        from a in Account,
          where: a.institution_id == ^institution_id and a.external_account_id == ^ext_id
      )

    case existing do
      nil ->
        %Account{}
        |> Account.changeset(Map.put(attrs, :institution_id, institution_id))
        |> Repo.insert()

      account ->
        account
        |> Account.changeset(attrs)
        |> Repo.update()
    end
  end
end
