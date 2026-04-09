defmodule Xactions.Accounts.AccountsTest do
  use Xactions.DataCase

  alias Xactions.Accounts
  alias Xactions.Accounts.{Institution, Account}
  import Xactions.Fixtures

  describe "create_institution/1" do
    test "creates institution with valid attrs" do
      attrs = institution_attrs(%{name: "Test Bank"})
      assert {:ok, %Institution{} = inst} = Accounts.create_institution(attrs)
      assert inst.name == "Test Bank"
      assert inst.status == "active"
    end

    test "encrypts credential_username at rest" do
      {:ok, inst} =
        Accounts.create_institution(
          institution_attrs(%{credential_username: "myuser"})
        )

      raw = Xactions.Repo.one!(from i in Institution, where: i.id == ^inst.id, select: i)
      assert raw.credential_username == "myuser"

      raw_binary =
        Xactions.Repo.query!("SELECT credential_username FROM institutions WHERE id = ?", [inst.id])

      [[db_val]] = raw_binary.rows
      refute db_val == "myuser"
    end

    test "returns error for missing name" do
      assert {:error, changeset} = Accounts.create_institution(%{sync_method: "browser"})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error for invalid sync_method" do
      assert {:error, changeset} =
               Accounts.create_institution(institution_attrs(%{sync_method: "invalid"}))

      assert %{sync_method: _} = errors_on(changeset)
    end
  end

  describe "list_institutions/0" do
    test "returns all institutions" do
      inst1 = institution!()
      inst2 = institution!()
      ids = Accounts.list_institutions() |> Enum.map(& &1.id)
      assert inst1.id in ids
      assert inst2.id in ids
    end
  end

  describe "get_institution!/1" do
    test "returns institution by id" do
      inst = institution!()
      assert Accounts.get_institution!(inst.id).id == inst.id
    end

    test "raises for missing id" do
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_institution!(0) end
    end
  end

  describe "update_institution_status/2" do
    test "updates status to valid value" do
      inst = institution!()
      assert {:ok, updated} = Accounts.update_institution_status(inst, "syncing")
      assert updated.status == "syncing"
    end

    test "valid status transitions" do
      inst = institution!()
      for status <- ~w(active syncing mfa_required credential_error error inactive) do
        assert {:ok, _} = Accounts.update_institution_status(inst, status)
      end
    end
  end

  describe "disconnect_institution/1" do
    test "deletes institution and cascades to accounts and transactions" do
      inst = institution!()
      account = account!(%{institution_id: inst.id})
      Accounts.disconnect_institution(inst)

      assert Xactions.Repo.get(Institution, inst.id) == nil
      assert Xactions.Repo.get(Account, account.id) == nil
    end
  end

  describe "create_account/1" do
    test "creates manual account without institution" do
      attrs = account_attrs(%{is_manual: true})
      assert {:ok, %Account{}} = Accounts.create_account(attrs)
    end

    test "creates linked account with institution" do
      inst = institution!()
      attrs = account_attrs(%{institution_id: inst.id})
      assert {:ok, %Account{} = acc} = Accounts.create_account(attrs)
      assert acc.institution_id == inst.id
    end

    test "returns error for invalid type" do
      assert {:error, changeset} = Accounts.create_account(account_attrs(%{type: "invalid"}))
      assert %{type: _} = errors_on(changeset)
    end
  end
end
